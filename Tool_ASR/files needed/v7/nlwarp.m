function [f,g,h] = nlwarp(type,parms)
%
% Provide a family of nonlinear warping functions
%
%     Creation date:   August 25, 2008
%     Programmer:      Chen,Zhengqing
%     Updates:         Auguest 27, 2008
%     Modification Made by: S.A.Zahorian
%     Modi_2nd: Adding Sigmoid as warping option. by CZQ on 16-NOV-2008.

%***********
% Input:
%***********
% * TYPE: the specific type of non-linear warping to use.
%   'B' for Bilinear
%   'M' for Mel-scale 
%   'K' for Kaiser Window
%   'G' for Gaussian
%   'N' for Non-symmetric Window
%   'S' for Sigmoid (18-NOV-2008,CZQ)

% * parms, short for 'parameters'.
%    A 2 or 3 element vector of parameters
%     parms(1)  = N = number of samples for each returned vector
%     parms(2)  =  parameter which controls degree of warping
%     parms(3)  =  parameter which controls degree of warping (not always needed)
%     details of parms(2)  and parms(3)  depend on warping type (see below)

%---------------------------------------------------
% For Bilinear, 'type' is 'B', 'parms' are [N,alpha]
%  range for alpha: usually less than 1 
%  typical values for alpha: choice around 0.45
%---------------------------------------------------

%--------------------------------------------------------------------
% For Mel-scale, 'type' is 'M', 'parms' are [N,k]
  %% k is to control the log mel-scale's shape
  %% the smaller the k, the more mass put on the 'head' of log curve
%   range for k: usually less than 1
%   typical values for k: didn't figure out optimal number yet
%--------------------------------------------------------------------

%--------------------------------------------------------
% For Gaussian Window, parameters are [N,alpha]
% Range of alpha: found to be within [-8,8] 
% The bigger the alpha, the narrower the BV concentrates 
% Typical alpha: choice around 2.5 to 3
%--------------------------------------------------------

%-------------------------------------------
% For Kaiser Window, parameters are [N,beta]
% Range of beta:   0 to 100
% Typical beta:   5
%-------------------------------------------

%--------------------------------------------------------
%% 18-NOV-2008(CZQ)
%% For Sigmoid warping, parameters are [N,a,b]
%%% Where 'a' controls the degree of warping(sharpness)
%%%     without going too wild, let's set a ~ [4,64];
%%%       'b' controls the focus hump, centered on x=b
%%%     without going too wild, let's set b ~ (0,1);
%--------------------------------------------------------

%  02-02-2011 (James Wu)
%  Time warping option available now known as 'N'
%  warping level is detedmined by 3 parameters in cp_fea13.ini (or other
%  specific setup file
%  Time_warp_fact1&2 : sigma values.   Controlling window shap  {values change from
%                      (0~1)}
%  shf:  shifting factor.  A window with smaller shf has an emphasis on the
%        prior part of speech context.  {value change from (0~1)}. 

% *************************************************************************

%***********
% output:
%***********
%*  f: the monotonously increasing,differentiable function within [0,1].
%      (f is the warping function)
%*  g: the derivative of f, scaled so that sum over [0,1] = 1.
%   ?? Do we really need this scaling so that sum(g) = 1 ??
%*  h: the inverse function of f.
%      (also regard 'h' as the non-uniformly distributed samples)
% (the points from the 'h' set, warped by f,
%  will generate uniformly distributed samples between [0,1])


x0 = [0:1/(parms(1)-1):1];
N_len = parms(1);

switch type
    case 'N'      % No warping (standard basis vector )
        g=sqrt(2/N_len)*ones(1,N_len);
        f=([1:N_len]-0.5)./N_len;
        h=[];
    case 'B' % original algorithm by Montri
% function [BV,delta,delta1]=comp_bvf(BTWC,N_startf,N_finalf,IP,flag);
    BTWC = parms(2); N_startf = 0; N_finalf = parms(1)-1;
    [delta]=biliwarp(BTWC,N_startf,N_finalf);
    g = delta; g = g/sum(g);
    f = zeros(1,length(g));
        for i = 1:length(g)-1
            f(i+1) = f(i) + g(i+1);
        end
    f = f/max(f);
    x = f;
 %Compute the inverse warping function
      y = (0:(N_len-1)) + 0.5;
      y = y/(N_len);
      h = interp1(f,y,y,'linear');
   

    case 'B1'  % Bilinear, strictly according to the formula in paper
        a = parms(2);
        f = x0 + 1/pi*atan(a*sin(2*pi*x0)./(1-a*cos(2*pi*x0)));        
        g = 1+0.31831*(2*a*cos(2*pi*x0).*pi./(1-a*cos(2*pi*x0))-...
            2*a^2*sin(2*pi*x0).^2./(1-a*cos(2*pi*x0)).^2*pi)...
            ./(1+a^2*sin(2*pi*x0).^2./(1-a*cos(2*pi*x0)).^2);
        x = f;         
 %Compute the inverse warping function
      y = (0:(N_len-1)) + 0.5;
      y = y/(N_len);
      h = interp1(f,y,y,'linear');
      
    case 'K' % Kaiser-Window
        N = parms(1); beta = parms(2); 
        g = kaiser(N,beta); g = g'; g = g/sum(g);
        f = cumsum(g,2);
        f = f/max(f);
        h = f;

    case 'M'  % Mel-Scale
        k = parms(2); C = 1/log10(1+1/k);
        x = k*(10.^(x0/C)-1);    %  computes freq in HZ from equal mels
        f = C*log10(1+x0/k);       %computes freq in mels from equal Hz
        g = C/log(10)*(1./(x0+k));

 %Compute the inverse warping function
      y = (0:(N_len-1)) + 0.5;
      y = y/(N_len);
      h = interp1(f,y,y,'linear');
      
    case 'G' % Gaussian Window
        N = parms(1); alpha = parms(2);
        g = gausswin(N,alpha); g = g'; g = g/sum(g);
        f = zeros(1,length(g));
        f = cumsum(g,2);
        f = f/max(f);
        x = f;
        
 
        
 %Compute the inverse warping function
      y = (0:(N_len-1)) + 0.5;
      y = y/(N_len);
      h = interp1(f,y,y,'linear');
      
    case 'N1'  % Non-Symmetric

      N = parms(1);        %read in all parameters
      sig_left  = parms(3);
      sig_right = parms(4); 
      shf       = parms(5);
      
      mp = round(N*shf);                  %set meeting point
   
      w1 = gausswin(mp*2, 1/sig_left);    % compute the left part of the window 
      w2 = gausswin((N-mp)*2, 1/sig_right);% compute the right part of the window 
    
      wlh = w1(1:mp);                     % combine the window together        
      wrh = w2((N-mp):end);               % smoothlizing the connection pt.
      amp_dv = wlh(end) - wrh(1);
      wrh(:) = wrh(:) + amp_dv;                     
   
      g = [wlh; wrh(2:end)];             
      g = g - min(g); g=g' ; g = g/sum(g);     % normalize the amplitude to [0,1]
      f = cumsum(g,2);
      f = f/max(f);
      h = f;
    
%18-NOV-2008 --------------------------------------------------------------
    case 'S' % Sigmoid
        N = parms(1); a = parms(2); b = parms(3);
        % N of Samples
        % a controls degree of warping, reasonable range of a: [4,64]
        % b controls the location of focus hump, reasonable range of b: (0,1)
        A = ((1+exp(a*b))*(1+exp(a*b-a)))/(exp(a*b)-exp(a*b-a));
        B = (1+exp(a*b-a))/(exp(a*b-a)-exp(a*b));
        x0 = [0:1/(N-1):1];
        h = b-1/a.*log(A./(x0-B)-1); %h is the non-uniform samples
        %y0 = A./(1+exp(a*(b-x0)))+B;
        f = A./(1+exp(a*(b-x0)))+B;
        g = A*a*exp(a*(b-x0))./((1+exp(a*(b-x0)).^2));
        g = g/sum(g);
        % g is the derivative of f
        % subplot(2,1,1);stem(h,f);
        % subplot(2,1,2);plot(h,g,'r');legend('Derivative');
%--------------------------------------------------------------------------

end
%      g = g/sum(g);


%plot(x0,f);grid on;hold on; plot(x0,g,'r');grid on;hold off;
%legend('Differentiable Nonlinear warping Function','Derivative of the warping Function');


%
% sub-routines
%
% sub-routine for moving averaging a vector
function xm = movavg(x)
    a = 1;
    b = 1/length(x)*ones(1,length(x));
    xm = filter(b,a,x);
%-------------------------------------------
% sub-routine for 'bilinear warping'
function [delta] = biliwarp(BTWC, N_startf, N_finalf)
%
N_f_samp = N_finalf - N_startf + 1;
%  w1 =  N_startf: N_finalf+1 ;
w1  = 1: (N_f_samp+1);
w1 =  ((w1-.5).*pi)./(N_f_samp+1);

WARP=w1+(2*atan((BTWC*sin(w1))./(1.-(BTWC*cos(w1)))));

SLOPE = 2.0* pi/(WARP(N_f_samp+1)+ WARP(N_f_samp)- WARP(1)- WARP(2));
B = 0.5 * (-SLOPE) * (WARP(1) + WARP(2));

%   Compute the derivative of the warping function
for j = 1:N_f_samp
    delta(j) =  WARP(j+1) - WARP(j);
end
delta = delta/(delta(1));
%--------------------------------------------------------------------
        
