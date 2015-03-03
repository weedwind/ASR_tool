% This file creates a file list 

path_wave = fullfile('..\data','train_wave','');
directory=dir(path_wave);
l=length(directory);
path_list=fullfile('lists','');
if ~exist(path_list, 'dir')
          mkdir(path_list);
end
listfile=[path_list,'\','wavefile.lst'];
fid=fopen(listfile,'w');
for i=3:l
   fwrite(fid, sprintf('%s\\%s\n',path_wave, directory(i,1).name));
end
fclose(fid);
