/*
* Modified center loss layer for segmentation.
* Author: Wei Zhen @ IIE, CAS
* Create on: 2016-12-25
* Last Modified: 2017-10-23
*/

#include <vector>

#include "caffe/filler.hpp"
#include "caffe/layers/center_loss_layer.hpp"
#include "caffe/util/math_functions.hpp"

namespace caffe {

template <typename Dtype>
__global__ void Compute_distance_data_gpu(int nthreads,
		 const Dtype* bottom_label,
		 Dtype* distance_data,
		 const Dtype* bottom_data, 
		 const Dtype* center, 
		 const int dim, const int c,
		 bool is_param_propagate_down_,
		 Dtype* variation_sum_data,
		 int* label_counter_,
		 float label_bottom_factor,
		 const int label_width, const int data_width,
		 const int* ignore_label, const int ignore_label_size,
		 Dtype* hw_flags) {
	CUDA_KERNEL_LOOP(index, nthreads) {
	    // convert data idx to label idx
	    const int y = int(index / data_width);
	    const int x = index % data_width;
	    const int y_ = int(y * label_bottom_factor);
	    const int x_ = int(x * label_bottom_factor);
	    const int label_idx = y_*label_width + x_;
            const int label_value = static_cast<int>(bottom_label[label_idx]);
	    // ignore label
	    bool ignore_label_flag = false;
	    for (int i = 0; i < ignore_label_size; i++) {
		if (ignore_label[i] == label_value)
		    ignore_label_flag = true;
	    }
	    if (ignore_label_flag)    continue;
            // D(n,c,y,x) = X(n,c,y,x) - C(c,Y(n,1,y,x))
            distance_data[index] = bottom_data[index] - center[label_value*dim + c];
	    // compute center diff
	    if (is_param_propagate_down_) {
		// variation_sum_data(Y(n,1,y,x), c) -= D(n,c,x,y) + 2x center_mutual_distance{finished in backward}
		if (hw_flags != NULL) {								// hard awared mode
			if (hw_flags[index] > 0) {						// flag>0 => true; flag<0 => false
			    variation_sum_data[label_value*dim + c] -= distance_data[index];
			    label_counter_[label_value]++;
			}
		}
		else {
			variation_sum_data[label_value*dim + c] -= distance_data[index];
			label_counter_[label_value]++;
		}
	    }
        }
}

template <typename Dtype>
__global__ void Compute_inter_loss_term_gpu(int nthreads,
		 const Dtype* bottom_label,
		 Dtype* distance_data,
		 const int dim, const int c,
		 const Dtype* distance_inter,
		 int* label_counter_,
		 float label_bottom_factor,
		 const int label_width, const int data_width,
		 const int* ignore_label, const int ignore_label_size,
		 const float lambda_, const bool is_hard_aware_,
		 Dtype* hw_flags) {
	CUDA_KERNEL_LOOP(index, nthreads) {
	    // convert data idx to label idx
	    const int y = int(index / data_width);
	    const int x = index % data_width;
	    const int y_ = int(y * label_bottom_factor);
	    const int x_ = int(x * label_bottom_factor);
	    const int label_idx = y_*label_width + x_;
            const int label_value = static_cast<int>(bottom_label[label_idx]);
	    // ignore label
	    bool ignore_label_flag = false;
	    for (int i = 0; i < ignore_label_size; i++) {
		if (ignore_label[i] == label_value)
		    ignore_label_flag = true;
	    }
	    if (ignore_label_flag)    continue;
	    // if don't use hard aware mode or use hard aware mode and the flag>0,
	    //    then propagate down inter loss diff
	    if (is_hard_aware_==false || (is_hard_aware_==true && hw_flags[index]>0)) {
		distance_data[index] -= 2 * lambda_ / label_counter_[label_value] * distance_inter[label_value*dim+c];
	    }
	    // else, if use hard aware mode and the flag<=0, then do nothing
	    else {}
        }
}

template <typename Dtype>
void CenterLossLayer<Dtype>::Forward_gpu(const vector<Blob<Dtype>*>& bottom,
    const vector<Blob<Dtype>*>& top) {
  const int num = bottom[0]->num();
  const int dim = bottom[0]->channels();
  const int label_height = bottom[1]->height();
  const int label_width = bottom[1]->width();
  const int data_width = bottom[0]->width();

/*
  // find shortest center distance for each center
  Dtype tmp_distance = 1e20;
  Dtype* tmp_sub = (Dtype*)malloc(dim*sizeof(Dtype));
  Dtype* distance_inter = center_mutual_distance.mutable_cpu_data();
  const Dtype* center = this->blobs_[0]->cpu_data();
  for (int i = 0; i < label_num_; ++i) {
    if (find(ignore_label_.begin(), ignore_label_.end(), i) != ignore_label_.end())  continue;
    for (int j = 0; j < label_num_; ++j) {
	if (find(ignore_label_.begin(), ignore_label_.end(), j) != ignore_label_.end())  continue;
	if (i == j)  continue;
	// |current center (i) - another center (j)|^2, i != j
	caffe_sub(dim, center+i*dim, center+j*dim, tmp_sub);
	Dtype tmp = caffe_cpu_dot(dim, tmp_sub, tmp_sub);
	if (tmp < tmp_distance) {
	    tmp_distance = tmp;
	    caffe_copy(dim, tmp_sub, distance_inter+i*dim);
	}
    }
  }
*/
  // accumulate all mutual center distances
  Dtype* tmp_sub = (Dtype*)malloc(dim*sizeof(Dtype));
  Dtype* distance_inter = center_mutual_distance.mutable_cpu_data();
  // reset mutual center distances
  caffe_set(center_mutual_distance.count(), (Dtype)0., distance_inter);
  const Dtype* center = this->blobs_[0]->cpu_data();
  for (int i = 0; i < label_num_; ++i) {
    if (find(ignore_label_.begin(), ignore_label_.end(), i) != ignore_label_.end())  continue;
    for (int j = 0; j < label_num_; ++j) {
	if (find(ignore_label_.begin(), ignore_label_.end(), j) != ignore_label_.end())  continue;
	if (i == j)  continue;
	// |current center (i) - another center (j)|^2, i != j
	caffe_sub(dim, center+i*dim, center+j*dim, tmp_sub);
	caffe_axpy(dim, (Dtype)1./label_num_, tmp_sub, distance_inter+i*dim);
    }
  // L_{D} = max(ld_margin_ - center_mutual_distance^2, 0)
//printf("%f %f\n",caffe_cpu_dot(dim, distance_inter+i*dim, distance_inter+i*dim), this->ld_margin_);
  if (caffe_cpu_dot(dim, distance_inter+i*dim, distance_inter+i*dim) > this->ld_margin_)
    caffe_set(dim, (Dtype)0., distance_inter+i*dim);
  }
  
  // convert ignore label vector into array
  int* cu_ignore_label = NULL;
  cudaMalloc((void**)&cu_ignore_label, this->ignore_label_.size() * sizeof(int));
  // NOTE!!! first param is number of byte, not number of a data
  caffe_gpu_memcpy(this->ignore_label_.size() * sizeof(int), &this->ignore_label_[0], cu_ignore_label);

  // prepare hard aware flags
  Dtype* hw_flags = NULL;
  if (bottom.size() == 3 && this->is_hard_aware_ == true) {	// hard awared mode
	hw_flags = this->hard_aware_flags_.mutable_cpu_data();
  }

  // the i-th distance_data
  for (int n = 0; n < num; ++n) {
    for (int c = 0; c < dim; ++c) {
	const int c_idx = n*dim+c;
	const Dtype* bottom_label = bottom[1]->gpu_data()+n*label_height*label_width;
	const Dtype* bottom_data = bottom[0]->gpu_data()+c_idx*inner_num_;
	Dtype* distance_data = distance_.mutable_gpu_data() + c_idx*inner_num_;
	Compute_distance_data_gpu<Dtype><<<CAFFE_GET_BLOCKS(inner_num_), CAFFE_CUDA_NUM_THREADS>>>
		(inner_num_,					//nthreads
		 bottom_label,					//bottom_label
		 distance_data,					//distance_data
		 bottom_data,					//bottom_data
		 this->blobs_[0]->gpu_data(), dim, c,		//center, dim, c
		 this->param_propagate_down_[0], 		//is_param_propagate_down_
		 variation_sum_.mutable_gpu_data(),		//variation_sum_data
		 label_counter_.mutable_gpu_data(),		//label_counter_
		 this->label_bottom_factor,			//label_bottom_factor
		 label_width, data_width,			//label_width, data_width
		 cu_ignore_label, this->ignore_label_.size(),   //ignore_label, ignore_label_size
		 hw_flags);					//hard aware flags
    }
  }
  // is use inter loss term, compute its diff
  if (this->has_inter_loss_term_ == true) {
    for (int n = 0; n < num; ++n) {
      for (int c = 0; c < dim; ++c) {
	const int c_idx = n*dim+c;
	const Dtype* bottom_label = bottom[1]->gpu_data()+n*label_height*label_width;
	const Dtype* bottom_data = bottom[0]->gpu_data()+c_idx*inner_num_;
	Dtype* distance_data = distance_.mutable_gpu_data() + c_idx*inner_num_;
	Compute_inter_loss_term_gpu<Dtype><<<CAFFE_GET_BLOCKS(inner_num_), CAFFE_CUDA_NUM_THREADS>>>
		(inner_num_,					//nthreads
		 bottom_label,					//bottom_label
		 distance_data,					//distance_data
		 dim, c,					//dim, c
		 center_mutual_distance.gpu_data(),		//distance_inter
		 label_counter_.mutable_gpu_data(),		//label_counter_
		 this->label_bottom_factor,			//label_bottom_factor
		 label_width, data_width,			//label_width, data_width
		 cu_ignore_label, this->ignore_label_.size(),   //ignore_label, ignore_label_size
		 this->lambda_, this->is_hard_aware_,		//lambda_, is_hard_aware_
		 hw_flags);
      }
    }
  }

  // compute loss
  Dtype loss = caffe_cpu_dot(distance_.count(), distance_.cpu_data(), distance_.cpu_data());
  loss = loss / num / Dtype(2);
  top[0]->mutable_cpu_data()[0] = loss;

  cudaFree(cu_ignore_label);
  free(tmp_sub);
}

template <typename Dtype>
void CenterLossLayer<Dtype>::Backward_gpu(const vector<Blob<Dtype>*>& top,
    const vector<bool>& propagate_down, const vector<Blob<Dtype>*>& bottom) {

  // Gradient with respect to centers
  if (this->param_propagate_down_[0]) {
    Dtype* center_diff = this->blobs_[0]->mutable_cpu_diff();
    const Dtype* variation_sum_data = variation_sum_.cpu_data();
    const int* label_counter__ = label_counter_.cpu_data();
    const int dim = bottom[0]->channels();

    caffe_set(this->blobs_[0]->count(), (Dtype)0., center_diff);
    // center's diff from other centers, old: update after late_iter_, new: is controlled by has_inter_loss_term_ flag
    if (this->has_inter_loss_term_ == true) {
	// second param is the balance weight between two different gradients
	caffe_axpy(dim*label_num_, this->lambda_*(-2), center_mutual_distance.cpu_data(), center_diff);
	//if (count_ == this->late_iter_+1)
	//    LOG(INFO) << "Start computing mutual center diff.";
    }

    for (int label_value = 0; label_value < label_num_; label_value++) {
      // ignore label
      if (find(ignore_label_.begin(), ignore_label_.end(), label_value) != ignore_label_.end())  continue;
      caffe_axpy(dim, bottom[0]->channels()/(label_counter__[label_value] + (Dtype)1.), variation_sum_data + label_value*dim, center_diff + label_value*dim);
    }

/*Dtype a=0, b=0, c=0;
for (int i = 0; i < dim; i++){
a+=center_mutual_distance.cpu_data()[1*dim+i]*this->lambda_;
b+=variation_sum_data[1*dim+i]/(label_counter__[1] + (Dtype)1.)*bottom[0]->channels();
c+=center_diff[1*dim+i];
}
const Dtype* test_val = center_mutual_distance.cpu_data()+(1*dim);
printf("%f %f %f %f\n",a,b,c, caffe_cpu_dot(dim, test_val, test_val));*/


    // reset variation_sum_
    caffe_set(variation_sum_.count(), (Dtype)0., variation_sum_.mutable_cpu_data());
    // reset label counter
    caffe_set(label_counter_.count(), (int)0., label_counter_.mutable_cpu_data());
  }
  // Gradient with respect to bottom data 
  if (propagate_down[0]) {
    caffe_cpu_scale(distance_.count(), top[0]->cpu_diff()[0] / bottom[0]->num(), distance_.cpu_data(), bottom[0]->mutable_cpu_diff());
    //if (count_ == this->late_iter_+1)
    //  LOG(INFO) << "Start backpropagating data gradient.";
  }
  if (propagate_down[1]) {
    LOG(FATAL) << this->type()
               << " Layer cannot backpropagate to label inputs.";
  }
}

INSTANTIATE_LAYER_GPU_FUNCS(CenterLossLayer);

} // namespace caffe
