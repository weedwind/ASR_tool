
%    March 21, 2012
%    Update April 3, 2012,  April 4, 2012



%    Test of different nonlinear sigmoidal type functions

%   map  the range of -1  to 1  to same range ,  but with sigmoidal
%   type nonlinearity

%     function y =  nonlin2(a, b, x)


%    this function is is used to nonlinearly map  the x vector
%    to the y vector,  using the sigmoidal nonlinearity defined
%    by parameters  a,  b,  c

%     this is intended for nonlinear amplitude scaling of speech spectral data
%     after log scaling

%     written right now  to work on each frame,  leaving dynamic range
%     unchanged,

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
  
      a = 3;    % 3;
      b = 0   ; %-2;
      c = 0   ; %-.5;


      t = 0:200;
      x = 10*sin(2*pi*t/50) + t/200;

%      x = 1:201;

      x_len = length(x);
      x_max = max(x);
      x_min = min(x);




      x_axis =  1:x_len;
      figure(1)

      plot (x_axis, x)
      axis([1 x_len  x_min x_max]);
      title ('Orignal vector')
      pause


      step_x0 = 2/(x_len-1);
      x0= -1: step_x0: 1;

      K = 2;

      y0 = a*x0 - b;
      z  = K* ((1 ./(1 + exp(-y0))) +c);




%     Now linearly rescale to fit to -1 1 range on z
      z_min = min(z);
      z_max = max(z);

      G = 2/(z_max-z_min);

%      offset =  G*z_min- 1;
%      z1 = G*z - offset -2;

       offset = -G*(z_max + z_min)/2;
       z1     =  G*z+ offset;




      figure(2)
      plot (x0, z1)
      axis([-1 1 -1 1]);
      title(' Sigmoid nonlinearity ')

      pause


%     first map x from x_min to x_max linearly to the range [-1, 1]



%       step_yy = (x_max - x_min)/(x_len-1);

%       step_xx = 2.0/(x_len- 1);

%       xx =  -1:step_xx:1;
%       yy =   x_min: step_yy: x_max;

       G = 2/(x_max-x_min);
       offset = -G*(x_max + x_min)/2;
       xx     = G*x+ offset;

%      Now convert xx to rounded integers
%      1 to x_len


       offset = (x_len+ 1)/2;
       G = (x_len-1)/2;
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



%       xxx =  interp1(z1,xx,x0);

       xxx =  z1(i_xx);

      figure (4)
      plot (x_axis, xxx);
      axis([1 x_len  -1 1]);
      title ('Non Linearly scaled vector to -1 1 range')
      pause




 %  Now linearly map back to original range

       offset = (x_max+ x_min)/2;
       G = (x_max-x_min)/2;
       y = G*xxx + offset;

    figure(5)
    plot (x_axis,y)
    axis([1 x_len x_min  x_max]);
    title(' Nonlinearly scaled original vector, back to original range ')
    pause




