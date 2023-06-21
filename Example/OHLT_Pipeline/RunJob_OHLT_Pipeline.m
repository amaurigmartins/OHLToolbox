% OHLT run
% Project description:
% -------------------
% Sample input data file for the example discussed in:
%
%Martins-Britto, Amauri G., et al. “Influence of Lossy Ground on High-Frequency Induced Voltages on Aboveground Pipelines by Nearby Overhead Transmission Lines.” IEEE Transactions on Electromagnetic Compatibility, vol. 64, no. 6, Institute of Electrical and Electronics Engineers (IEEE), Dec. 2022, pp. 2273–82, doi:10.1109/temc.2022.3201874.
%
close all;
clear all;
clc;
format longEng;
%
% Flags and options
ZYprnt = boolean(1); 
Modprnt = boolean(1); 
ZYsave = boolean(1); 
export2EMTP = boolean(1); 
export2PCH = boolean(1); 
FD_flag = 0; 
decmp_flag = 9; 
global pythoncall; pythoncall = 'python3';
% jobid will be appended to whatever file or plot generated by this run
jobid = 'OHLT_Pipeline';
%
% Library functions
currmfile = mfilename('fullpath');
currPath = currmfile(1:end-length(mfilename()));
WORKDIR = 'YOUR/PATH/GOES/HERE';
addpath([WORKDIR 'ZY_OHTL_pul_funs']);
addpath([WORKDIR 'mode_decomp_funs']);
addpath([WORKDIR 'FD_soil_models_funs']);
addpath([WORKDIR 'export_fun']);
addpath([WORKDIR 'bundle_reduction_funs']);
addpath([WORKDIR 'JMartiModelFun']);
addpath([WORKDIR 'JMartiModelFun']);
addpath(fullfile(WORKDIR,'JMartiModelFun','functions'));
addpath(fullfile(WORKDIR,'JMartiModelFun','vfit3'));
%
% Frequency range
f = transpose(logspace(1,6,100));
freq_siz=length(f);
%
% Line characteristics
[line_length,ord,soil,h,d,Geom]=LineData_fun();
%
% Calculations
tic
[Ztot_Carson,Ztot_Noda,Ztot_Deri,Ztot_AlDe,Ztot_Sunde,Ztot_Pettersson,Ztot_Semlyen,Ztot_Wise,Ztot_under,Ztot_OvUnd,Nph] = ...
Z_clc_fun(f,ord,ZYprnt,FD_flag,freq_siz,soil,h,d,Geom,ZYsave,jobid); % Calculate Z pul parameters by different earth approaches
[Ytot_Imag,Ytot_Pettersson,Ytot_Wise,Ytot_Papad,Ytot_OvUnd,sigma_g_total,erg_total,Nph] = ...
Y_clc_fun(f,ord,Modprnt,FD_flag,freq_siz,soil,h,d,Geom,ZYsave,jobid); % Calculate Y pul parameters by different earth approaches
[Zch_mod,Ych_mod,Zch,Ych,g_dis,a_dis,vel_dis,Ti_dis,Z_dis,Y_dis] = ...
mode_decomp_fun(Ztot_Wise,Ytot_Wise,f,freq_siz,Nph,decmp_flag,sigma_g_total,erg_total,ZYprnt,jobid); % Modal decomposition
toc
%
% Save files
OHLT_Pipeline_data.Z = Ztot_Wise;
OHLT_Pipeline_data.Y = Ytot_Wise;
OHLT_Pipeline_data.Zch_mod = Zch_mod;
OHLT_Pipeline_data.Ych_mod = Ych_mod;
OHLT_Pipeline_data.Zch = Zch;
OHLT_Pipeline_data.Ych = Ych;
OHLT_Pipeline_data.g_dis = g_dis;
OHLT_Pipeline_data.a_dis = a_dis;
OHLT_Pipeline_data.vel_dis = vel_dis;
OHLT_Pipeline_data.Ti_dis = Ti_dis;
OHLT_Pipeline_data.Z_dis = Z_dis;
OHLT_Pipeline_data.Y_dis = Y_dis;
OHLT_Pipeline_data.sigma_g_total = sigma_g_total;
OHLT_Pipeline_data.erg_total = erg_total;
if (export2EMTP); punch2emtp; end
if (export2PCH); makeJmartiModel; end
if ZYsave
    fname = fullfile(currPath,'OHLT_Pipeline_output.mat');
    save(fname,'OHLT_Pipeline_data');
    FolderName = fullfile(currPath,'plots');   
    mkdir(FolderName)
    FigList = findobj(allchild(0), 'flat', 'Type', 'figure');
    for iFig = 1:length(FigList)
        FigHandle = FigList(iFig);
        FigName   = get(FigHandle, 'Name');
        savefig(FigHandle, fullfile(FolderName,[FigName '.fig']));
    end
end
