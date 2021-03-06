#
# Align the size of one input feature map with the one from another input feature map 
#     using imresize function.
# Author: Wei Zhen @ IIE, CAS & Yingcai, UESTC
# Finish on: 2016-03-28
# Last modified: 2017-04-21

import caffe
import numpy as np
from skimage.transform import resize
import time
from multiprocessing import Pool as ThreadPool

# global function
def run_resize(map_arg):
    return resize(map_arg[0], map_arg[1], order=map_arg[2], preserve_range=True)

class BlobAlignLayer(caffe.Layer):
    """
	Resize feature maps in bottom[0] in the size of feature maps in bottom[1]
    """

    def setup(self, bottom, top):
	# check input/output length, one top and two bottoms are accepted
	if len(top) != 1:
	    raise Exception("Blob align layer only accepts one top")
	if len(bottom) != 2:
	    raise Exception("Blob align layer accepts two bottoms")
	# select interpolation algorithm
	self.inter_order = 0	# default bilinear
	if self.param_str == "nearest":
	    self.inter_order = 0
	elif self.param_str == "bilinear":
	    self.inter_order = 1
	elif self.param_str == "biquadratic":
	    self.inter_order = 2
	elif self.param_str == "bicubic":
	    self.inter_order = 3
	elif self.param_str == "biquartic":
	    self.inter_order = 4
	elif self.param_str == "biquintic":
	    self.inter_order = 5
	# open multiprocessing pool
	self.pool = ThreadPool(1)

    def reshape(self, bottom, top):
	# top/result has the same height and width as the second bottom/input
	#    and the same number and channel as the first bottom/input
	top_shape = np.array(bottom[0].data.shape)
	top_shape[2] = bottom[1].data.shape[2]
	top_shape[3] = bottom[1].data.shape[3]
	top[0].reshape(*top_shape)

    def forward(self, bottom, top):
	#time1 = time.time()
	# bottom[0] provides feature maps to be transformed
	# bottom[1] provides the aim height and width
	# two bottoms can vary in number and channel
	# 1. fetch aim size
	aim_size = np.array(bottom[1].data.shape[2:])
	#aim_size = aim_size[np.newaxis,:]
	#aim_size = np.tile(aim_size, (bottom[0].channels,1))
	# 2. resize each feature map using imresize function
	for batch in range(bottom[0].num):
	    map_arg = []
	    for channel in range(bottom[0].channels):
		map_arg.append([bottom[0].data[batch,channel,...], aim_size, self.inter_order])
	    top[0].data[batch,...] = self.pool.map(run_resize, map_arg)

	#print '#########################',time.time()-time1

    def backward(self, top, propagate_down, bottom):
	#time1 = time.time()
	# resize top's diff to the size of bottom[0]
	aim_size = np.array(bottom[0].diff.shape[2:])
	for batch in range(top[0].num):
	    map_arg = []
	    for channel in range(top[0].channels):
		map_arg.append([top[0].diff[batch,channel,...], aim_size, self.inter_order])
	    bottom[0].diff[batch, ...] = self.pool.map(run_resize, map_arg)
	# bottom[1].diff = 0
	bottom[1].diff[...] = 0
	#print '!!!!!!!!!!!!!!!!!!!!!!!!!',time.time()-time1
