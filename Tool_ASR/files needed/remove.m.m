fp=fopen('tridict','rt');
fout=fopen('tlist','wt');
while ~feof(fp)
    inline=fgetl(fp);
    if ~isempty(inline)
        [word, remain]=strtok(inline);
        fwrite(fout,sprintf('%s\n',remain));
    end
end
fclose(fp);
fclose(fout);

        