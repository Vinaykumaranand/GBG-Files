libname gbg "C:\Users\Jeffrey\Documents\School\GBG";

***1 DATA CLEANUP AND PREPARATION--------------------------------------;

*1.1 Concatenate "csboys" and "csgirls";
data gbg.csboysgirls;
	set gbg.csboys gbg.csgirls;
run;

*1.2 Drop variables from "csboysgirls" (otherwise they would interfere with the sampling process);
data gbg.csboysgirls (drop=selectionprob samplingweight Probability_of_Selection Sampling_Weight);
	set gbg.csboysgirls;
run;

*1.3 Take subset of "csboysgirls" (33-42 weeks only), also calculate a few new variables;
data gbg.csboysgirlsSUB;
	set gbg.csboysgirls;
		if gestage LE 32 then delete;
		if BirthWeight=. or BirthLength=. then delete;
		BMI= (BirthWeight/(BirthLength**2))*10000;
		recBMI=(1/BMI);
		ponderal=(BirthWeight/(BirthLength**3))*10000;
		lnweight=log(birthweight);
		lnlength=log(birthlength);
run;

***2 EXPLORATORY DATA ANALYSIS----------------------------;

*2.1 Sort "csboysgirlssub" by gestage;
proc sort data=gbg.combihome;
	by GestAge;
run;

*2.2a Calculate summary stats of several variables;

proc means data=gbg.csboysgirlsSUB mean min max;
	var birthweight birthlength BMI;
	class GestAge;
run;
ods rtf close;
	*Remark: Here we noticed that infants from the Cole et al. data had
			 lower BMI's than the Ferguson et al. data.

*2.2b Print only the mean BMI from the last step;
ods rtf ;
proc means data=gbg.csboysgirlsSUB mean;
	var BMI;
	class GestAge;
run;
ods rtf close;


***3. MACRO I: SAMPLING PROCEDURE & CALCULATION OF BENN POWERS----------------;

%macro samples();

*Take 1,000 stratified samples per gestage weighted toward smaller BMI infants;
	%do i=1 %to 500;
	%let d1=trial&i.;
		proc surveyselect data=gbg.csboysgirlsSUB 
							method=pps 
							sampsize=(3 5 6 24 50 132 184 276 213 92)
		                   	out=trial&i.;
						   	size recBMI;
		   					strata gestage;
		run;

*Regression model to calculate Benn powers;
		proc reg data=&d1; 
			model lnweight=lnlength;
			by gestage;
			ods output parameterestimates=ParEstallresponse&i;
		run;

*Regression model to calculate Benn powers;
	%let d2=ParEstallresponse&i.;
		data benn&i.;
		    set &d2;
				if variable = "Intercept" then delete;
				bennallresponseest =estimate;
				keep gestage bennallresponseest;
		run;

	%end;
%mend;

%samples()

***4. MACRO II: CONCATEATE DATA GENERATED FROM PREVIOUS MACRO----------------;

*4.1 Initiate concatenation of benn power datasets;
data gbg.FINALbmi;
	set benn1;
run;

*4.2 Concatenation of benn power dataset;
%macro concat();
	%do i=2 %to 1000;
	%let d1=benn&i.;
		data gbg.finalbmi;
			set gbg.finalbmi &d1;
		run;
	%end;
%mend;
%concat()

***5. GROUPWORK: COMBINE JEFF'S DATASET WITH WENDY'S----------------;

data gbg.final;
	set gbg.final finalwendy;
run;

***6. DATA VISUALIZATION--------------------------------;

*6.1 Sort "final" dataset by 'gestage';
proc sort data=gbg.final;
	by gestage;
run;

*6.2 Make histograms of 'benn powers' by for all 'gestages';
ods rtf;
%macro histogram();
	%do i=33 %to 42;
		proc sgplot data=gbg.final;
			histogram bennallresponseest;
			density bennallresponseest;
			where gestage=&i.;
			title "Distribution of Benn Powers for Week &i.";
		run;
	%end;
%mend;
%histogram;
ods rtf close;

*6.3 Print summary statistics of the sampled benn powers;
proc means data=gbg.final n min q1 median mean q3 max;
	class gestage;
run;

*6.4a Rename 'benallresponseest' to 'Benn_Index' for next graphic;
data gbg.final2;
	set gbg.final;
	rename bennallresponseest=Benn_Power;
run;

*6.4b Generate proc univariate graphics (Histogram+Boxplot+NormalPlot);
ods rtf;
proc univariate data=gbg.final2 normal plot;
	var benn_Power;
	by gestage;
run;
ods rtf close;

*6.5a Create dataset of Cole's Results (for boxplot w/ Cole's datapoints);
data gbg.cole;
	input GestAge Benn_Power_Cole;
	datalines;
		33 7.3
		34 3.8
		35 2.7
		36 3.8
		37 3.4
		38 2.8
		39 2.7
		40 2.4
		41 2.5
		42 2.4
	;
run;

*6.5b Concatenate 'cole' and 'final' datasets;
data gbg.finalcole;
set gbg.cole gbg.final;
run;

*6.5c Make boxplot/scatterplot hybrid;
proc sgplot data=gbg.finalcole;
	hbox bennallresponseest / legendlabel="Ferguson et al. simulations" category=GestAge;
	scatter y=GestAge x=Benn_Power_Cole / legendlabel="Cole et al. calculation"
	        markerattrs=(color=red symbol=circlefilled size=8);
			title "Figure 1: Boxplots of Benn Power Distribution by Gestational Age";
			xaxis label="Benn Power";
			yaxis label="Gestational Age (Weeks)";
			ods graphics / antialias=on antialiasmax=10100;
run;


***7 POST HOC ANALYSIS I: BENN POWERS FOR "CSBOYSGIRLS" DATASET--------------------------;

*7.1 Sort by gestage;
proc sort data=gbg.csboysgirlssub; 
	by gestage;
run;

*7.2a Regression;
proc reg data=gbg.csboysgirlssub; 
	model lnweight=lnlength;
	by gestage;
	ods output parameterestimates=ParEstallresponse;
run;

*7.2b Calculate Benn Indicies by GestAge;
data gbg.csboysgirlsbenn;
    set ParEstallresponse;
		if variable = "Intercept" then delete;
		bennallresponseest =estimate;
		keep gestage dependent variable bennallresponseest;
run;

*7.3 Print Results;
ods rtf; 
proc print data=gbg.csboysgirlsbenn (drop=dependent variable);
	title "Benn Powers of all Preterm Infants in Ferguson et al. 1998-2006 Dataset";
run;
ods rtf close;

*8 POST HOC ANALYSIS II: USE OPTION "SIZE BMI" INSTEAD OF "SIZE RECBMI"------------------------

*8.1a We tried running sampling macro with "size BMI" instead of "size recBMI";
%macro samples();
	%do i=501 %to 1000;
	%let d1=trial&i.;
		proc surveyselect data=gbg.csboysgirlsSUB method=pps 
						  	sampsize=(3 5 6 24 50 132 184 276 213 92)
                     		out=trial&i.;
				   	 		size BMI;
   							strata gestage;
		run;

		proc reg data=&d1; 
			model lnweight=lnlength;
			by gestage;
			ods output parameterestimates=ParEstallresponse&i;
		run;

	%let d2=ParEstallresponse&i.;
		data benn&i.;
		    set &d2;
			if variable = "Intercept" then delete;
			bennallresponseest =estimate;
			keep gestage bennallresponseest;
		run;

	%end;
%mend;
%samples()

*8.1b Initiate concatenation of benn power datasets;
data gbg.FINALbmi;
	set benn1;
run;

*8.1c Concatenation of benn power dataset;
%macro concat();
	%do i=1 %to 1000;
	%let d1=benn&i.;
		data gbg.finalbmi;
			set gbg.finalbmi &d1;
		run;
	%end;
%mend;
%concat()

*8.2 Sort output dataset by 'gestage';
proc sort data=gbg.finalbmi;
	by gestage;
run;

*8.3a Concatenate "cole" and "finalbmi" datasets for next graphic;
data gbg.finalbmi2;
	set gbg.cole gbg.finalbmi;
run;

*8.3b Create visualization where sampling=BMI (not recBMI);
proc sgplot data=gbg.finalbmi2;
	hbox bennallresponseest / legendlabel="Ferguson et al. simulations (where size=BMI)" category=GestAge;
	scatter y=GestAge x=Benn_Power_Cole / legendlabel="Cole et al. calculation"
        markerattrs=(color=red symbol=circlefilled size=8);
		title "Boxplots of Benn Power Distribution by Gestational Age";
		xaxis label="Benn Power";
		yaxis label="Gestational Age (Weeks)";
run;

