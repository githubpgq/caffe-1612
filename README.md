<<<<<<< HEAD
## My Caffe development repo @ KFXW

My own Caffe development branch with some tools:

- Multi Mean Field Iteration (transfer from [CRF-RNN caffe](https://github.com/torrvision/crfasrnn))
- Segmetation Accuracy Layer (micro averaged F1 score or Mean IoU/Jaccard score, with plugin files acommedating to various datasets)
- hard awared statistical contextual loss for parsing (under construction)
- Blob Align (python layer, resize a feature map to the same size of another feature map)
- imgResize (python layer)
- salientArea (Pyhton layer, convert parsing labels to 0/1 binary map - bg or object)
- image seg data layer (transfer from [Deeplab v1 caffe](https://github.com/TheLegendAli/DeepLab-Context))
- dense crf layer (transfer from [Deeplab v1 caffe](https://github.com/TheLegendAli/DeepLab-Context))

=======
>>>>>>> caffe-bvlc-dev/master
# Caffe

[![Build Status](https://travis-ci.org/BVLC/caffe.svg?branch=master)](https://travis-ci.org/BVLC/caffe)
[![License](https://img.shields.io/badge/license-BSD-blue.svg)](LICENSE)

Caffe is a deep learning framework made with expression, speed, and modularity in mind.
<<<<<<< HEAD
It is developed by the Berkeley Vision and Learning Center ([BVLC](http://bvlc.eecs.berkeley.edu)) and community contributors.
=======
It is developed by Berkeley AI Research ([BAIR](http://bair.berkeley.edu))/The Berkeley Vision and Learning Center (BVLC) and community contributors.
>>>>>>> caffe-bvlc-dev/master

Check out the [project site](http://caffe.berkeleyvision.org) for all the details like

- [DIY Deep Learning for Vision with Caffe](https://docs.google.com/presentation/d/1UeKXVgRvvxg9OUdh_UiC5G71UMscNPlvArsWER41PsU/edit#slide=id.p)
- [Tutorial Documentation](http://caffe.berkeleyvision.org/tutorial/)
<<<<<<< HEAD
- [BVLC reference models](http://caffe.berkeleyvision.org/model_zoo.html) and the [community model zoo](https://github.com/BVLC/caffe/wiki/Model-Zoo)
=======
- [BAIR reference models](http://caffe.berkeleyvision.org/model_zoo.html) and the [community model zoo](https://github.com/BVLC/caffe/wiki/Model-Zoo)
>>>>>>> caffe-bvlc-dev/master
- [Installation instructions](http://caffe.berkeleyvision.org/installation.html)

and step-by-step examples.

<<<<<<< HEAD
=======
## Custom distributions

 - [Intel Caffe](https://github.com/BVLC/caffe/tree/intel) (Optimized for CPU and support for multi-node), in particular Xeon processors (HSW, BDW, Xeon Phi).
- [OpenCL Caffe](https://github.com/BVLC/caffe/tree/opencl) e.g. for AMD or Intel devices.
- [Windows Caffe](https://github.com/BVLC/caffe/tree/windows)

## Community

>>>>>>> caffe-bvlc-dev/master
[![Join the chat at https://gitter.im/BVLC/caffe](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/BVLC/caffe?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Please join the [caffe-users group](https://groups.google.com/forum/#!forum/caffe-users) or [gitter chat](https://gitter.im/BVLC/caffe) to ask questions and talk about methods and models.
Framework development discussions and thorough bug reports are collected on [Issues](https://github.com/BVLC/caffe/issues).

Happy brewing!

## License and Citation

Caffe is released under the [BSD 2-Clause license](https://github.com/BVLC/caffe/blob/master/LICENSE).
<<<<<<< HEAD
The BVLC reference models are released for unrestricted use.
=======
The BAIR/BVLC reference models are released for unrestricted use.
>>>>>>> caffe-bvlc-dev/master

Please cite Caffe in your publications if it helps your research:

    @article{jia2014caffe,
      Author = {Jia, Yangqing and Shelhamer, Evan and Donahue, Jeff and Karayev, Sergey and Long, Jonathan and Girshick, Ross and Guadarrama, Sergio and Darrell, Trevor},
      Journal = {arXiv preprint arXiv:1408.5093},
      Title = {Caffe: Convolutional Architecture for Fast Feature Embedding},
      Year = {2014}
    }
