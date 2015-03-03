function [BVT,warp_t2] = comp_bvt(Block_length_min, Block_length_max, Block_jump,...
                        Num_DCS, Time_warp_fact, Norm_flag)

%function BVT = comp_bvt(Block_length_min, Block_length_max, Block_jump,...
%                        Num_DcS, Time_warp_fact, Norm_flag);
%
%  This function is used to compute sets of "warped" cosine
%  basis vectors over time  
%
%
%  Inputs:
%   Block_length_min = minimum block length in frames
%   Block_length_max = maximum block length in frames
%   Block_jump       = block spacing in frames
%   Num_DCS          = number of DCSs
%   Time_warp_fact   = time warping factor 
%   Norm_flag        = 1: normalize, 0: do not normalize BV
%
%  Outputs:
%   BVT              = 3-D matrix, BVT(i, j, k) represents i-th element of j-th basis
%                      vector of k-th set of basis vectors
%                      Since, each set of bv has different length, BVT is allocated
%                      for maximum length. Final part of matrix is filled with zeros
%                      for shorter sets
%
%                      size(BVT,1) = length of longest basis vector (Block_length_max)
%                      size(BVT,2) = number of basis vectors of each set (= Num_DCS)
%                      size(BVT,3) = number of sets (of various sizes) of basis vectors
%   warp_t2          =  array which holds the ideal sampling for spectrum
%                       within each block-- non uniform
%
%
%  Subroutine used: gs1.m
%
%  Note:  See cp_bv2.c
% 
%
%  Programmer  :  Montri
%  Date        :  12/09/99
%  Revision    :  03/22/00 Montri, use sqrt of sum to rescale BV
%                          This is different from cp_bv2 where BV never really be
%                          normalized (bv'*bv != I), 
%					   03-27-00 Montri, Since Stefan scaling works a little better than
%                          sqrt(sum()) sclaing in Phonetic Recognition, I will keep
%                          Stefan scaling (dividing all element of BVT by sum of first
%                          BV. And since with sqrt(sum()) scaling gives same BVT set as
%                          orthonormalized BVT set, now we can use sqrt(sum()) scaling
%                          by turning on the orth flag and if simple scaling (Stefan's)
%                          is to be used, turning off the orth flag.


% how many set of BVs do we need to compute?
NumSets = fix( 1 + (Block_length_max - Block_length_min) / Block_jump );

LargestBlockLength = Block_length_min + (NumSets-1) * Block_jump;

BVT = zeros(LargestBlockLength, Num_DCS, NumSets); % pre-allocated matrix

BlockLength = Block_length_min;  % start at minimum length

for iSet = 1:NumSets 
   
   if BlockLength == 1
      BVT(1,1,iSet) = 1.0;
   elseif BlockLength > 1
      Time_warp_fact_adj = Time_warp_fact;
      if Block_length_max > Block_length_min
         Time_warp_fact_adj = Time_warp_fact * (BlockLength - Block_length_min) / ...
            (Block_length_max - Block_length_min);
      end
      KaiserWnd = comp_kaiser(BlockLength, Time_warp_fact_adj);
      
      % compute relative sampling positions
      dw = KaiserWnd(1:BlockLength-1) + KaiserWnd(2:BlockLength);
      dw = [dw; 0]; % add one last element (won't be used) to avoid error
      
      % rescale dw to match total range
      scale = sum(dw);
      range = (pi/BlockLength) * (BlockLength-1);
      scale = range/scale;
      
      dw = dw*scale;
      
      % compute basis vectors for the current set
      for iDCS=1:Num_DCS
         w = 0.5*pi/BlockLength;
         for iFrm=1:BlockLength
            BVT(iFrm, iDCS, iSet) = KaiserWnd(iFrm) * cos(w*(iDCS-1)) / BlockLength;
            w = w + dw(iFrm);
         end
	      % new code added as of 3-22-00  to normalized each BVT set
         % summ = sqrt(sum(BVT(:, iDCS, iSet).^2));
         % BVT(:, iDCS, iSet) = BVT(:, iDCS, iSet)/summ;
      	% end new code added
      end
    
      % check the normalization flag
	   if Norm_flag == 1
        	BVT(:, :, iSet) = gs1(BVT(:, :, iSet));
      else
      % calculate a sum over all values of the first DCS
        	avg = sum(BVT(:, 1, iSet));
      % rescale the basis vectors
      	BVT(:,:,iSet) = BVT(:,:,iSet) / avg;
   	end
   end
   % get ready for next block size
   BlockLength = BlockLength + Block_jump;
   % make sure that block size is not exceed max size
   % this should not happen if specs. were read with rd_spec.m
   if BlockLength > Block_length_max 
      BlockLength = Block_length_max;
   end;
end

%    Add in feature  to compute the warping function


     warp_t1= BVT(:,1,1);
     warp_t1 = zeros(1,BlockLength);
     warp_t1(1) = BVT(1,1,1);
       for i = 2:BlockLength
          warp_t1(i) = BVT(i,1,1) + warp_t1(i-1);
       end;



%     plot (warp_t1);
%     pause

     x = warp_t1;
     y = ( (1:BlockLength)- 1)/ (BlockLength-1);


     warp_t2 = interp1(x,y,y,'pchip');
%     plot(warp_t2)
%     pause
%     warp_t2
%    rescale warp_t2 do that range is 1 to BlockLength, but non uniform
     warp_t2 = warp_t2 - warp_t2(1);
     warp_t2 = (warp_t2/warp_t2(BlockLength)) *(BlockLength-1);
     warp_t2 = 1 +warp_t2;

%     pause












