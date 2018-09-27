$ONTEXT
Sept 21

$OFFTEXT

OPTIONS PROFILE =3, RESLIM   = 2100, LIMROW   = 5, LP = CPLEX, MIP = cplex, RMIP=cplex, NLP = CONOPT, MINLP = DICOPT, MIQCP = CPLEX, SOLPRINT = OFF, decimals = 8, optcr=0.01, optca=0.01, threads =8, integer4=0;

********************************************************************************
* run_time_total recorder
SCALAR start_time, end_time, run_time_total;
*-------------------------------------------------------------------------------

** sets later to be defined in input file
SETS T times/t1*t24/;
SETS SCEN scenarios /scen1*scen500/;

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
$INCLUDE solar_scenarios_500.csv
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
*                                begin model
********************************************************************************
POSITIVE VARIABLES P(scen,t), Q(scen,t), X(scen,t), Y(T) ;
VARIABLES OBJ;
BINARY VARIABLE W(scen,t), Z(scen) ;

EQUATIONS
        Objective
        Const1(scen,t)    balance constraint
        Const2(scen,t)    max charge
        Const3(scen,t)    max discharge
        Const_chance_1(scen,t)    chance constraint big M
        Const_chance_2            chance constraint sum probabilities

        ;

Objective.. OBJ=E= SUM(T,Prices(T, 'REW')*Y(T) - probability*Sum(scen, Prices(T, 'CHAR')* P(scen,t) + Prices(t, 'DISCHAR') * Q(scen,t)  ) )    ;

Const1(scen,t)$((ord(t) le card(t)) and (ord(t) gt 1)).. X(scen,t+1) =E= X(scen,t) + eta* P(scen,t) - (1/eta)* Q(scen,t) ;

Const2(scen,t).. P(scen,t) =L= max_charge * W(scen,t)  ;
Const3(scen,t).. Q(scen,t) =L= max_discharge * ( 1- W(scen,t) )  ;

Const_chance_1(scen,t).. Y(T) + P(scen,t) -  Q(scen,t) -SOLAR(scen,t) =L= Z(scen)*BigM(scen,t) ;
Const_chance_2..      sum(scen, z(scen)) =L= threshold;


*** bounds on any variables
x.up(scen,t) = BigX ;
x.lo(scen,t) = LowX ;
q.up(scen,t) = max_discharge ;
p.up(scen,t) =  max_charge ;
x.fx(scen,'t1') = X_0 ;


option limrow = 10000 ;
MODEL  SCHEDULE    /ALL/ ;

start_time=jnow;
SOLVE SCHEDULE USING MIP MAXIMIZING OBJ;
display obj.l ;

end_time = jnow;
run_time_total = ghour(end_time - start_time)*3600 + gminute(end_time - start_time)*60 + gsecond(end_time - start_time);
