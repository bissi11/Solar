clear all;
close all;

% Scenario generation
nscen = 100;
nt = 3;
scen = randn(nt,nscen);

% Plot the bands
nfig = 2;                   % figure number
nbands = 5;                 % number of bands in the figure
innercol = [0.1 0.9 0.5];   % color for the inner band (RGB)
outercol = [0.1 0.4 0.2];   % color for the outer band (RGB)
[legstrg] = centquantplot(scen,nfig,'scenarios',nbands,innercol,outercol)

% Plot the original dataset
hold on;
for i = 1:nt
    scatter(repmat(i,nscen,1),scen(i,:))
end

% Print the legend
legend(char(legstrg))