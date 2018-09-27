function [legstrg] = centquantplot(data,fig,descr,nbands,darkcol,brightcol,vec_x);

% function plotquant(data,nbands,fig,color)
%
% This function allows to plot quantiles of data as bands
%
if nargin < 3
    descr = '';
end
if nargin < 4
    nbands = 4;
end
if nargin < 6
    darkcol = [.5 0.1 0.95];
    brightcol = [.5 0.8 0.95];
end

nhor = size(data,1);
ndat = size(data,2);

if nargin < 7
    ax = [1:nhor,fliplr([1:nhor])];
else
    ax = [vec_x,fliplr([vec_x])];
end

% data = sort(data,2);
% 
% quant = data(:,max(1,round(ndat*(0:2*nbands)/(2*nbands))))';
quant = quantile(data',(0:2*nbands)/(2*nbands));


figure(fig); hold on; box on;
%ax = [1:nhor,fliplr([1:nhor])];

for i = 1:nbands
    int = [quant(i,:),fliplr(quant(end-i+1,:))];
    h = area(ax,int);
    set(h,'FaceColor',brightcol-(brightcol-darkcol)*((i-1)/(nbands-1)),'EdgeColor','none');
end
    
legstrg = java_array('java.lang.String', nbands);
for i = 1:nbands
    legstrg(i) = java.lang.String([num2str(round(100*(nbands-i+1)/nbands)) '% ' descr]);
end