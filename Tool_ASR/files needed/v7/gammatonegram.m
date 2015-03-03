function [Y,F] = gammatonegram(X,SR,TWIN,THOP,N,FMIN,FMAX,USEFFT,WIDTH)

% Sampling rate SR
if nargin < 2;  SR = 16000; end
% Frame Length TWIN 
if nargin < 3;  TWIN = 0.02; end
% Hop size between each frame THOP
if nargin < 4;  THOP = 0.002; end
% Number of channels N
if nargin < 5;  N = 16; end
if nargin < 6;  FMIN = 100; end
if nargin < 7;  FMAX = 8000; end
if nargin < 8;  USEFFT = 1; end
if nargin < 9;  WIDTH = 1.0; end


if USEFFT == 0 

  % Use malcolm's function to filter into subbands
  %%%% IGNORES FMAX! *****
  [fcoefs,F] = MakeERBFilters(SR, N, FMIN);
  fcoefs = flipud(fcoefs);

  XF = ERBFilterBank(X,fcoefs);

  nwin = round(TWIN*SR);

%  XE = [zeros(N,round(nwin/2)),XF.^2,zeros(N,round(nwin/2))];
  XE = [XF.^2];

  hopsamps = round(THOP*SR);

  ncols = 1 + floor((size(XE,2)-nwin)/hopsamps);

  Y = zeros(N,ncols);

%  winmx = repmat(window,N,1);

  for i = 1:ncols
%    Y(:,i) = sqrt(sum(winmx.*XE(:,(i-1)*hopsamps + [1:nwin]),2));
    Y(:,i) = sqrt(mean(XE(:,(i-1)*hopsamps + [1:nwin]),2));
  end

else 
  % USEFFT version
  % How long a window to use relative to the integration window requested
  winext = 1;
  twinmod = winext * TWIN;
  % first spectrogram
  nfft = 2^(ceil(log(2*twinmod*SR)/log(2)));
  nhop = round(THOP*SR);
  nwin = round(twinmod*SR);
  [gtm,F] = fft2gammatonemx(nfft, SR, N, WIDTH, FMIN, FMAX, nfft/2+1);
  % perform FFT and weighting in amplitude domain
  Y = 1/nfft*gtm*(abs(specgram(X,nfft,SR,nwin,nwin-nhop))).^2;
  % or the power domain?  doesn't match nearly as well
  %Y = 1/nfft*sqrt(gtm*abs(specgram(X,nfft,SR,nwin,nwin-nhop).^2));
end



