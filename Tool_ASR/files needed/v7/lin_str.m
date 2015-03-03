%    lin_str.m

%    Creation date:   June 12, 2012


%    Linearly map array x  to y =  ax+b
%    Such that min of x  maps to specified y_min
%    and max 0f x mnaaps to specified  y_max


     function y = lin_str(x, y_min, y_max)



     x_min =  min(x);
     x_max =  max(x);


     a = (y_max-y_min)/(x_max - x_min);

     b = y_min -a*x_min;

     y = a*x + b;


