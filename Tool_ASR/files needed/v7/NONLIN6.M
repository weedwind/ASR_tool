
%    March 21, 2012
%    Update April 3, 2012,  April 4, 2012
%    Update:   April 25, 2012,  June 12, 2012


%    Test of different nonlinear sigmoidal type functions for
%    amplitude scaling of speech spectral amplitudes

%    map the range of -1  to 1  to same range ,  but with sigmoidal
%    type nonlinearity

%     function y =  nonlin6(a, b, ratio, x, Num_steps)


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


%     a,b,c,   control  type of nonlinearity

%     Let c = 0 for now

%     suggest trying these four cases

%     a,b =  10,0   =  steep symmetric nonlinearity
%     a,b =  3,0    =  mild  symmetric nonlinearity
%     a,b =  3,3  = compression at low levels,  linear  at high levels
%     a,b =  2,2  = milder from of 3,3, but same general effect
%     a,b =  4,1  = more compression at lows than highs
  
      a = 3;  % 3;
      b = 0;   ; %-2;
      c = 0;   ; %-.5;
      ratio = .75;

%     checks
      if (a < .01)
         a = .01
      end;

      if (b <  .01)
        b = .01
      end;

      if (ratio < .01)
        ratio = .01
      end;

      if (ratio > 1)
         ratio = 1
      end;

      Num_steps = 500;

      t = 0:200;
      x = 10*sin(2*pi*t/50) + t/200;
      x_max_overall = 50;
      x_min_overall =  -50;


      x_len = length(x);
%      x_len = Num_steps;


      x_max0= max(x);
      x_min0 = min(x);
      x_max = x_max_overall;    %max(x);
      x_min = x_min_overall;    %min(x);




      x_axis =  1:x_len;
      figure(1)

      plot (x_axis, x)
      axis([1 x_len  x_min x_max]);
      title ('Orignal vector')
      pause


      step_x0 = 2/(Num_steps-1);
      x0= -1: step_x0: 1;

      K  = 2;
      c1 = 0;

      y0 = a*x0 - b;
      z  = K* ((1 ./(1 + exp(-y0))) +c1);




%     Now linearly rescale to fit to -1 1 range on z

       z1 = lin_str(z,-1, 1);



      figure(2)
      plot (x0, z1)
      axis([-1 1 -1 1]);
      title(' Sigmoid nonlinearity ')

      pause


      size(x0)
      size(z1)
      pause



      if (ratio <  1.0)

      x0_max = ratio*1 ;
      i0_max = floor(Num_steps/2 + (x0_max * (Num_steps/2)))
      z1_max = z1(i0_max);

      x0_partial = x0(1:i0_max);
      z1_partial = z1(1:i0_max);

      figure(3)
      plot (x0_partial, z1_partial)
      axis([-1 x0_max -1 z1_max]);
      title(' Sigmoid nonlinearity with partial range')

      pause

      Step_size = (x0(i0_max) + 1)/(Num_steps-1)
      x_interp = -1:Step_size:x0(i0_max);
      z1_partial_interp = interp1(x0_partial,z1_partial, x_interp);
      pause


      figure(4)
      plot (x_interp, z1_partial_interp)
      axis([-1 x0_max -1 z1_max]);
      title(' Sigmoid nonlinearity with partial range, interpolated')

      pause


%     Now let us map  both x_interp  and z1_partial_interp to [-1 1 ]  range

      x_interp1 = lin_str(x_interp, -1 , 1);
      z1_partial_interp1 = lin_str(z1_partial_interp, -1 , 1);


      figure(5)
      plot (x_interp1, z1_partial_interp1)
      axis([-1 1 -1 1]);
      title(' Partial Sigmoid nonlinearity, rescaled to -1 1 range')

      pause

      end;   % end of loop not using entire range of sigmoid


%      map x from x_min to x_max linearly to the range [-1, 1]


       xx     = lin_str(x, -1, 1);


%      Now convert xx to rounded integers
%      1 to Num_steps


       offset = (Num_steps + 1)/2;
       G = (Num_steps-1)/2;
       i_xx = round (G*xx + offset);

       plot (i_xx)
       min (i_xx)
       max (i_xx)
       pause


       xx_min = min(xx);
       xx_max = max(xx);


       figure(3)
      plot (x_axis, xx);
      axis([1 x_len  xx_min xx_max]);
      title ('Linearly scaled vector')
      pause





 %  Now map  x1 with the nonlinear sigmoid  to [-1, 1]


     if (ratio < 1)
         xxx =  z1_partial_interp1(i_xx);
      else
         xxx =  z1(i_xx);
      end;


      figure (4)
      plot (x_axis, xxx);
      axis([1 x_len  -1 1]);
      title ('Non Linearly scaled vector to -1 1 range')
      pause




 %  Now linearly map back to original range


       y = lin_str(xxx,x_min0, x_max0);


    figure(5)
    plot (x_axis,y)
    axis([1 x_len x_min  x_max]);
    title(' Nonlinearly scaled original vector, back to original range ')
    pause




