
%    March 21, 2012
%    Update    April 3, 2012,  April 4, 2012
%    Update:   April 25, 2012,  June 12, 2012,  July 2, 2012


%    Test of different nonlinear sigmoidal type functions for
%    amplitude scaling of speech spectral amplitudes

%    map the range of -1  to 1  to same range ,  but with sigmoidal
%    type nonlinearity

function y =  nonlin7(a, b, ratio, x, Min_overall, Max_overall, Num_steps, Type)


%    this function is is used to nonlinearly map  the x vector
%    to the y vector,  using the sigmoidal nonlinearity defined
%    by parameters  a,  b,  c, ratio  using Num_steps  to
%    approximate nonlinearity

%    The basic form of function is to map spectra to -1 1 range,  then
%    nonlinearly map  to -1 1 range nonlinearly,  and then
%    back to  original range

%    This is intended for nonlinear amplitude scaling of speech spectral data
%     after log scaling

%    Can either work on frame basis,  or ca work on a sentence level
%    but leaving dynamic range Unchanged

%    suggested settings for a, b, c  are given below
%

%     Inputs

%     a,b,ratio,   control  type of nonlinearity

%     Let c = 0 ---  could be made a parameter

%     suggest trying these four cases

%     a,b =  10,0   =  steep symmetric nonlinearity
%     a,b =  3,0    =  mild  symmetric nonlinearity
%     a,b =  3,3  = compression at low levels,  linear  at high levels
%     a,b =  2,2  = milder from of 3,3, but same general effect
%     a,b =  4,1  = more compression at lows than highs
%     ratio--  typically .5  to 1

%     x  =   input vector to be scaled
%     Min_overall   == Minimum value in x vectors over an utterance
%     Max_overall   == Maximum value in x vectors over an utterance

%     Num_steps     =   Number of amplitude  steps--  typically 500
%

%              controls assemetry in nonlinearity

%     Type == 'local'  scaling depends on values in current x only
%          == 'global'  scaling depends on values in x vectors over utterance
%     Note  that Min_overall and Max_overall  are not used if Type = 'local'





%     checks to be sure parameters are in reasonable range
      if (a < .01)
         a = .01;
      end;

      if (b <  .01)
        b = .01;
      end;

      if (ratio < .01)
        ratio = .01;
      end;

      if (ratio > 1)
         ratio = 1;
      end;

      Num_steps = 500;


      x_len = Num_steps;


      if (Type == 1)

         x_max = max(x);
         x_min = min(x);
         x_max0 = x_max;
         x_min0 = x_min;


      end


      if (Type == 2)

        x_max = Max_overall;
        x_min = Min_overall;
        x_max0= max(x);   %x_max;   Oct 21, 2012
        x_min0= min(x);   %x_min;

      end




      x_len = Num_steps;
      step_x0 = 2/(x_len-1);
      x0= -1: step_x0: 1;

      K  = 2;
      c1 = 0;

      y0 = a*x0 - b;
      z  = K* ((1 ./(1 + exp(-y0))) +c1);



%     Now linearly rescale to fit to -1 1 range on z

       z1 = lin_str(z,-1, 1);
%      above checks ok--   7-13-12
%     Now linearly rescale to fit to -1 1 range on z

%      z_min = min(z);
%      z_max = max(z);
%
%      G = 2/(z_max-z_min);
%
%       offset = -G*(z_max + z_min)/2;
%       z1     =  G*z+ offset;



      if (ratio <  1.0)

      x0_max = ratio*1 ;
      i0_max = floor(Num_steps/2 + (x0_max * (Num_steps/2)));
      z1_max = z1(i0_max);

      x0_partial = x0(1:i0_max);
      z1_partial = z1(1:i0_max);


      Step_size = (x0(i0_max) + 1)/(Num_steps-1);
      x_interp = -1:Step_size:x0(i0_max);
      z1_partial_interp = interp1(x0_partial,z1_partial, x_interp);




%     Now let us map  both x_interp  and z1_partial_interp to [-1 1 ]  range

      x_interp1 = lin_str(x_interp, -1 , 1);
      z1_partial_interp1 = lin_str(z1_partial_interp, -1 , 1);



      end;   % end of loop not using entire range of sigmoid


%      map x from x_min to x_max linearly to the range [-1, 1]

%       xx     = lin_str(x, -1, 1);   % This does not work
%       since x_max  and x_min are in fact global max and min for all x vectors
%       and not likely max and min of this particular x

%       compare to nonlin6

       G = 2/(x_max-x_min);
       offset = -G*(x_max + x_min)/2;
       xx     = G*x+ offset;



%      Now convert xx to rounded integers
%      1 to Num_steps


       offset = (x_len + 1)/2;
       G = (x_len-1)/2;
       i_xx = round (G*xx + offset);




%       xx_min = min(xx);
%       xx_max = max(xx);



 %  Now map  x1 with the nonlinear sigmoid  to [-1, 1]


     if (ratio < 1)
         xxx =  z1_partial_interp1(i_xx);
      else
         xxx =  z1(i_xx);
      end;




 %  Now linearly map back to original range,  but note, for type 2,
 %  using global max  and min,   xxx does not have a range of -1 to 1
 %  did not test thoroughly,  but lin_str likely does not work


       y = lin_str(xxx,x_min0, x_max0);


%       offset = (x_max0+ x_min0)/2;
%       G = (x_max0-x_min0)/2;
%       y = G*xxx + offset;




