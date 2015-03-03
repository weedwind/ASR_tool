function y = loglimit(x,limit)
% y = loglimit(x,limit)
% return log(x) or log(limit) if x < limit
if (x < limit)
    y = log(limit);
else
    y = log(x);
end;