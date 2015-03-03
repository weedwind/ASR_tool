function [re_sam12]=gammatonebank(x,lowcf,highcf,numchans,fs,winsize,resample_factor,align)
%%parameters to be declared

if nargin<2
    lowcf = 100;
end
if nargin<3
    highcf = 8000;
end
if nargin<4
    numchans = 16;
end
if nargin<5
    fs = 16000;
end
if nargin<6
    winsize = 50; 
end
if nargin<7
    resample_factor = 32;
end
if nargin<8
   align = false;
end

if numel(x)~=max(size(x))
    error('x must be a vector')
end
x = reshape(x,1,length(x));

bms = zeros(numchans,length(x));
%% to generate Center Frequencies
cfs=MakeErbCFs(lowcf,highcf,numchans);


for c=1:numchans
%Center Frequency of each channel
cf=cfs(c);
if align
    B=1.019*2*pi*erb(cf);
    envelopecomptime = 3/B;
else
   envelopecomptime = 0;
end
shift=envelopecomptime;
intshift=round(shift*fs);
y = [x zeros(1,intshift)];
phasealign=-2*pi*cf*envelopecomptime;
phasealign=mod(phasealign,2*pi);
phasealign=phasealign/(2*pi*cf);

bw=1.019*erb(cf); % bandwidth of each channel

wcf=2*pi*cf; % radian frequency 
tpt=(2*pi)/fs;
a=exp(-bw*tpt);
gain=4*((bw*tpt)^4)/6; % based on integral of impulse response

kT=(0:length(y)-1)/fs;

q=exp(1i.*(-wcf.*kT)).*y; % shift down to d.c.
p=filter([1 0],[1 -4*a 6*a^2 -4*a^3 a^4],q); % filter: part 1
u=filter([1 4*a 4*a^2 0],[1 0],p); % filter: part 2
bms=gain*real(exp(1i*wcf*(kT(intshift+1:end)+phasealign)).*u(intshift+1:end)); % shift up in frequency
gamma_out = bms; %%Gammaton filter output
%%
%RECTIFIER
rect_out= abs(gamma_out);
%LOW PASS FILTER
y1 = fir1(winsize,1/fs);
y= filter(y1,1,rect_out);
save y;
y2= 20*log10(y);
save y2;
%RESAMPLE
re_sam11= resample(y2,1,resample_factor);
re_sam12(c,:) = re_sam11;
end
%%
save re_sam12;
[nrow, ncol] = size(re_sam12);
re_sam12 = (re_sam12(:,(winsize:ncol)));
