$ONTEXT
Sept 27
Lagrangian relaxation

$OFFTEXT

OPTIONS PROFILE =3, RESLIM   = 2100, LIMROW   = 5, LP = CPLEX, MIP = cplex, RMIP=cplex, NLP = CONOPT, MINLP = DICOPT, MIQCP = CPLEX, SOLPRINT = OFF, decimals = 8, optcr=0.01, optca=0.01, threads =8, integer4=0;

********************************************************************************
* run_time_total recorder
SCALAR start_time, end_time, run_time_total;
*-------------------------------------------------------------------------------

** sets later to be defined in input file
SETS T times/t1*t24/;
SETS SCEN scenarios /scen1*scen1000/;

ALIAS (T,TT);


** define battery  operation costs costs and solar selling prices

TABLE PRICES(t,*)
$ONDELIM
$INCLUDE battery_revenue.csv
$OFFDELIM
;

** define solar scenarios at all time periods
TABLE Solar(scen,t)
$ondelim
$INCLUDE solar_scenarios_1000.csv
$offdelim


* Scaling of Solar power scenarios ;
scalar scale ;
scale = 1;
Solar(scen,t) = scale* Solar(scen,t) ;


scalar PROBABILITY;
PROBABILITY = 1/CARD(scen);
;
scalar eta ;
*from Ben paper
eta = 0.9
;

parameters max_store(t), min_store(t), max_charge, max_discharge;


** define tolerance threshold
SCALAR tol, threshold;
TOL       = 0.05;
threshold = floor(card(scen)*TOL)  ;

parameter BigX, LowX, X_0 maximum minimum initial energy stored ;
parameter BigM(scen,t) find a good BigM ;

BigX = 960 ;
LowX = 0.2* BigX ;
X_0  = 0.5* BigX ;
max_charge =  0.5* BigX ;
max_discharge =  0.5* BigX ;

************** Find a Big M
* find Ntol + 1st value
parameter maxsolar(t), minsolar(t), dummysolar(scen,t) ;
maxsolar(t) =smax(scen,solar(scen,t)) ;
dummysolar(scen,t) = solar(scen,t) ;

scalar it ;
it = floor(card(scen)*tol) + 1;

* index of it
set dummy(scen);
* make the dum_iter go till at least the size of it
set dum_iter /dum_iter1*dum_iter100/;
loop(t,
loop(dum_iter$(ord(dum_iter)le it),
* find the smallest solar value for this t
         minsolar(t) = smin(scen,dummysolar(scen,t)) ;
* index of smallest solar value
         dummy(scen) = yes$(dummysolar(scen,t) eq minsolar(t)) ;
* make the smallest solar value large
         dummysolar(scen,t)$dummy(scen) =maxsolar(t) ;
); );
scalar G upper bound on q - p ;
G = min(BigX - LowX, max_discharge)  ;

BigM(scen,t)= G - solar(scen,t) + minsolar(t);
**********************************

********************************************************************************
* Lagrangian dual
* Let Const_chance_2 be the complicating constraint
*---------------------------------------------------------------------
********************************************************************************

parameter lambda;
parameter ldual value of Lagrangian dual ;
parameter bound total value of Lagrangian dual ;
variable bound_lr objective of Lagrangian dual;
scalar init_lambda, init_bound initial value of lambda dual LP objective from LP ;


********************************************************************************
*                                begin model
********************************************************************************
POSITIVE VARIABLES P(scen,t), Q(scen,t), X(scen,t), Y(T) ;
VARIABLES OBJ, BOUND_LR;
BINARY VARIABLE W(scen,t), Z(scen) ;

EQUATIONS
        Objective
        Const1(scen,t)    balance constraint
        Const2(scen,t)    max charge
        Const3(scen,t)    max discharge
        Const_chance_1(scen,t)    chance constraint big M
        Const_chance_2            chance constraint sum probabilities
        LR                lagrangian relaxation objective ;

        ;

Objective.. OBJ=E= SUM(T,Prices(T, 'REW')*Y(T) - probability*Sum(scen, Prices(T, 'CHAR')* P(scen,t) + Prices(t, 'DISCHAR') * Q(scen,t)  ) )    ;

Const1(scen,t)$((ord(t) le card(t)) and (ord(t) gt 1)).. X(scen,t+1) =E= X(scen,t) + eta* P(scen,t) - (1/eta)* Q(scen,t) ;

Const2(scen,t).. P(scen,t) =L= max_charge * W(scen,t)  ;
Const3(scen,t).. Q(scen,t) =L= max_discharge * ( 1- W(scen,t) )  ;

Const_chance_1(scen,t).. Y(T) + P(scen,t) -  Q(scen,t) -SOLAR(scen,t) =L= Z(scen)*BigM(scen,t) ;
Const_chance_2..      sum(scen, z(scen)) =L= threshold;

LR.. bound_lr =e=   SUM(T,Prices(T, 'REW')*Y(T) - probability*Sum(scen, Prices(T, 'CHAR')* P(scen,t) + Prices(t, 'DISCHAR') * Q(scen,t)  ) )
                         + lambda* (threshold - sum(scen, z(scen)))  ;


*** bounds on any variables
x.up(scen,t) = BigX ;
x.lo(scen,t) = LowX ;
q.up(scen,t) = max_discharge ;
p.up(scen,t) =  max_charge ;
x.fx(scen,'t1') = X_0 ;


********************************************************************************
* subgradient iteration parameters
********************************************************************************
set iter                 number of subgradient iterations /iter1*iter30/;
scalar num_iter          how many interations we did ;

scalar contin            stopping             /1/;
parameter stepsize;
scalar theta /2/;
scalar noimprovement /0/;
scalar upperbound ;
parameter gamma           subgradient          ;
parameter norm;
scalar lowerbound;
parameter lambdaprevious;
parameter deltalambda;
parameter results(iter,*);


model schedule / Objective,  Const1, Const2, Const3,  Const_chance_1, Const_chance_2/ ;
model schedule_LR / LR,  Const1, Const2, Const3,  Const_chance_1/ ;
********************************************************************************
* Find a upperbound on the problem : a LP solution
********************************************************************************
solve schedule using RMIP maximizing OBJ ;
init_lambda  = Const_chance_2.m ;
upperbound   = Obj.l ;
lambda       = init_lambda ;
display init_lambda ;

***************************************************************

********************************************************************************
* Find a lowerbound on the problem : a feasible solution
********************************************************************************
lowerbound =  0;
* Find a lower bound using a fixed value and solving MIP (a feasible solution)
* Choose z = 0 for now
z.up(scen) =0 ; ;
solve schedule using MIP maximizing Obj ;
lowerbound = Obj.l ;
parameter prev_y(t) store for warm start this feasible solution ;
prev_y(t) = y.l(t) ;

* Clear bound on z now
z.up(scen) = 1 ;

display lowerbound,upperbound,prev_y ;


********************************************************************************
* Solve the Lagrangian Dual problem now
********************************************************************************

option limrow = 0;
option limcol = 0;
schedule_LR.solprint = 0;
schedule_LR.optfile  = 1;

parameter ldual_iter(iter) obj function at each iteration ;

loop(iter$contin,
* pass a warm start
         y.l(t) = prev_y(t) ;
         SOLVE schedule_LR using MIP MAXIMIZING bound_lr;
         bound            = bound_lr.l ;
         if (schedule_LR.modelstat =18,  bound =100000000;  );
         results(iter,'objective')= bound ;
         prev_y(t) = y.l(t) ;

******************* check if theta needs be updated and update bounds
if (bound < upperbound,
         upperbound = bound;
         noimprovement = 0;
else
         noimprovement = noimprovement + 1;
         if (noimprovement > 1,
                 theta = theta/2;
                 noimprovement = 0;
         );
);
results(iter,'noimprov') = noimprovement;
results(iter,'theta') = theta;
results(iter,'status') = schedule_LR.modelstat;
*
******************** calculate step size
*
gamma =   threshold - sum(scen, z.l(scen))   ;
gamma$(abs(gamma) le 0.0001) = 0   ;
norm = gamma*gamma;

stepsize = theta*(bound-lowerbound)/norm;
results(iter,'step') = stepsize;
*
********************** update dual lambda
*
lambdaprevious = lambda ;
* for small enough values set gamma to be 0
lambdaprevious$(lambdaprevious le 0.0001) = 0;

$ontext
         if (gamma ge 0 and lambdaprevious =0,
                 lambda = lambdaprevious ; );
         if (gamma > 0 and lambdaprevious ge 0,
                 lambda = lambdaprevious - min(stepsize, lambdaprevious/gamma)*gamma ; );
         if (gamma < 0,
                 lambda = lambdaprevious - stepsize*gamma; );
$offtext
lambda = lambdaprevious + stepsize* gamma ;

* converged ?
*

deltalambda = abs(lambdaprevious-lambda) ;
results(iter,'deltalambda') = deltalambda;

if( deltalambda < 0.001,
           display "Converged";
           contin = 0;
);

num_iter = ord(iter) ;
);

display results, lowerbound, upperbound ;

