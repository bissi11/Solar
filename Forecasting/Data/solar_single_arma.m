% March 2018

%Trying 24 models for 24 hours. Excludes the night hours
% Data starts from May 8, 2013 00:00 ends at June 30, 2014 23:00

clc
clear all
%% Importing Data

%Raw has two columns, first is the actual, second is the forecast.
%First row of Raw is 0:00 on May 8, 2013.
%RawData=[];
Raw=[] ;
for i=1:388
    file_name=sprintf('1 (%d)/scenarios.csv',i) ; % read file name f
    A= xlsread(file_name);
    % Store only first two columns and without the first row
    A(1,:)=[]  ;  % delete first row
    B=A(:,1:2) ;  % % store first two rows
    Raw= [Raw; B] ; % concatenate below
end

Raw= Raw(:,1) ;

% We will force all values at times 0:00, 1:00, ...5:00 and 20:00,
% 21:00,...23:00 to be zero. Index is one more than this
night=[1,2,3,4,5,6,21,22,23,24] ; % These indices will have zero values


%% Split into training and testing data
% we have 388 days of data. Take first 270 days,
train = Raw(1:270*24); % approx 70% of data as training. Matrix of 270x24

%% Choose best ARMA model.
% Skip this step if you know the p,q values.
LOGL = zeros(4,4); %Initialize
PQ = zeros(4,4); % We will check a total of 4x4=16 models for each hour
P=[]; Q=[];
for p = 1:4
    for q = 1:4
        try % this try loop captures models with non-invertible polynomials and excludes them
            mod = arima(p,0,q);
            [fit,~,LOGL(p,q)] = estimate(mod,train,'print',false);
        catch ME
            P=[P p] ;Q =[Q q]; % store the values for which polynomial was not solvable, later we'll delete them
        end
        PQ(p,q) = p+q ;
    end
end

for i=1:numel(P)
    LOGL(P(i),Q(i)) = inf; % effectively remove elements which had unsolvable polynomial
end

% Calculate the BIC
LOGL = reshape(LOGL,p*q,1);
PQ = reshape(PQ,p*q,1);
[~,bic] = aicbic(LOGL,PQ+1,numel(train));
R=reshape(bic,p,q) ;
% note the smallest value of BIC in above matrix, rows give p columns give q
R(R==-Inf) = Inf;
[mini,ind] = min(R(:));
[p,q] = ind2sub(size(R),ind); % This is the model we will use

%%
% What gave the best BIC?
% display model parameters
mdl=estimate(arima(p,0,q),train);
EstMdl=mdl ;


%% Check predictive performance.
% Use a holdout sample to compute the predictive MSE of the model. Use the first 100
% observations to estimate the model, and then forecast the next 24
% periods. The number 100 0is arbitrary
% http://www.mathworks.com/help/econ/check-model-for-airline-passenger-data.html

pmse=zeros(24,1) ;
for i=1:24
    if ~ismember(i,night)  % if not part of the night indices
        y1 = Raw(numel(train)- 101+i: numel(train)+i-1);                         % 100 Presample values (for each hour)
        y2 = Raw(numel(train)+i) ;                                           % Actual value (for each hour)
        
        Mdl1 = estimate(EstMdl,y1);
        [yF1{i}, ymse{i}] = forecast(Mdl1,1,'Y0',y1);                              % the next one step prediction             
        pmse(i) = mean((y2-yF1{i}).^2);
    else
        yF1{i} = 0 ;
        ymse{i}= 0 ;
    end
end
yA=Raw(numel(train)+1:numel(train)+24);                                                           % Actual next values (24)
yF_dum=cell2mat(yF1);
yF=reshape(yF_dum,24,1);                                                                 % Forecast next values (24)
ymse_dum=cell2mat(ymse);
yMSE=reshape(ymse_dum,24,1);
figure
h1=plot(yA,'r','LineWidth',2)
hold on
h2=plot(yF,'k--','LineWidth',1.5)
h3 = plot(1:24,yF + 1.96*sqrt(yMSE),'r:',...
    'LineWidth',2);
plot(1:24,yF - 1.96*sqrt(yMSE),'r:','LineWidth',2);
xlim([1,24])
legend([h1 h2 h3],'Observed','Forecast',...
    '95% Confidence Interval');
title(['24-Period Solar Power Forecasts and Approximate 95% '...
    'Confidence Intervals'])
xlabel('Time')
ylabel('Solar Output (MWh)')
set(gca,'Xtick',1:24)
set(gca, 'XtickLabel',{'0:00','1:00','2:00','3:00','4:00','5:00','6:00','7:00','8:00','9:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00','19:00','20:00', '21:00', '22:00', '23:00'}) ;
xtickangle(45)
hold off

% Store model info in a file
info = [EstMdl.P, EstMdl.Q, EstMdl.Variance] ;

%% Check predictive performance using tests
% I think we cannot do the Ljung Box Test here because we make only one prediction... Better to the lbqtest on the Samples (below). But we can use the pmse


%% Create samples out of it
% create S samples, and write them to a file. You will need to manually
% change the file format tobe specific to what GAMS uses.
% Also, we took absolute values of the ones generated to remove negative ones.

S=2000;
% go back a 100 time periods (arbitrary)

for i=1:24
    if ~ismember(i,night)  % if not part of the night indices
        presamp = Raw(numel(train)- 101+i: numel(train)+i-1);                               % 100 Presample values (for hour i)
        Samp{i} = simulate(EstMdl,1,'NumPaths',S,'Y0',presamp);
    else
        Samp{i}=zeros(S,1)' ;
    end
    
end
Sample = [Samp{1}; Samp{2}; Samp{3}; Samp{4}; Samp{5}; Samp{6}; Samp{7}; Samp{8}; Samp{9}; Samp{10}; Samp{11}; Samp{12}; Samp{13}; Samp{14}; Samp{15}; Samp{16}; Samp{17}; Samp{18}; Samp{19}; Samp{20}; Samp{21}; Samp{22}; Samp{23}; Samp{24}];
Actual = Raw(size(train,1)+1: size(train,1),:) ;
Sample = max(Sample,0);


xlswrite(Sample');

% Plot these samples
figure

ymean= quantile(Sample', 0.5);
y10=   quantile(Sample',0.1) ;

plot(Sample) ;
hold on
h2=plot(y10,'k--','LineWidth',2.5, 'Color',[0 0 0])
hold on
h3=plot(ymean,'LineWidth',2.5, 'Color',[0 0 0])
legend([h2 h3],'10% quantile','Median');



xlabel('Hour')
ylabel('Solar energy (MWh)')
set(gca,'Xtick',1:24)
set(gca, 'XtickLabel',{'0:00','1:00','2:00','3:00','4:00','5:00','6:00','7:00','8:00','9:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00','19:00','20:00', '21:00', '22:00', '23:00'})
xtickangle(45)
hold off


%% Can check forecast performance

% Ljung Box test: https://www.mathworks.com/help/econ/lbqtest.html
% hLjung=0 means not enough evidence to reject the null hypothesis that the
% residuals of the returns are not autocorrelated. (0 means model is good)

% Engle's ARCH test:https://www.mathworks.com/help/econ/archtest.html
% hEngle=0 indicates failure to reject the no ARCH effects null hypothesis (0 means model is good)
for i=1:24
    if ~ismember(i,night)  % if not part of the night indices
        res= Sample(i,:) - mean(Sample(i,:))' ;
        [hLjung,pValue] = lbqtest(res,'lags',[5,10,15])
        [hEngle,pValue] = archtest(res)
    end
end

%% Metrics
% Mean Absolute Error
mean_absolute_error= mean(abs(yA-yF)) ;
% Root Mean Square Error
root_mean_sq_error = sqrt(mse(yA,yF)) ;

%% Smart Persistence model 
% Eqn 8 of Solar Forecasting in a Challenging Insular Context Philippe Lauret 1,*, Elke Lorenz 2 and Mathieu David 1

% Split data to hourly data
RawHour=zeros(388,24) ;
for j=1:388
    for i=1:24
        if ~ismember(i,night)  % if not part of the night indices
            RawHour(j,i) = Raw(i+24*(j-1)) ;
        end
    end
end

% Split into training and testing data
% we have 388 days of data. Take first 270 days,
train = RawHour(1:270,:); % approx 70% of data as training. Matrix of 270x24
h=3 ;
yP= mean(RawHour(size(train,1)-h+1: size(train,1),:));    
mean_absolute_error_persistence = mean(abs(yA-yP)) ;
root_mean_sq_error_persistence = sqrt(mse(yA,yP)) ;
