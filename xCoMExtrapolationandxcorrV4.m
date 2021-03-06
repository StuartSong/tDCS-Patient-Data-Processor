clear
close all
clc
warning('off','all')

%% Session number
currentFolder = pwd;
[filepath,Sessionnumber] = fileparts(currentFolder);

%% Import Data and Create Folder
mkdir DataPackage;
mkdir DataPackage\Figures;

ViconNames = dir('*.csv');
ViconTablenames = {ViconNames.name};
ViconTname = string(ViconTablenames);
ViconTablename = erase(ViconTname,'.csv');

VRNames = dir('*.txt');
VRTablenames = {VRNames.name};
VRTname = string(VRTablenames);
VRTablename = erase(VRTname,'.txt');

%% Record the Command Window
diary(strcat('./DataPackage/','Readme.txt'))

%% Decide fliping Trials after First Run
FlipTrials = [1 2] % number sequence of Trials that needs to be flipped
% Remember to delete the already generated datapackage folder

%% Loop for the section
for Trials = 1:length(ViconTablenames)
    ViconRawdata = readtable(ViconTname(Trials));
    VRRawdata = readtable(VRTname(Trials));
    ViconTime = ViconRawdata.Var1;
    VRTime = VRRawdata.Time*100;
    VRTime = VRTime-VRTime(1);
    ViconLLM_X = ViconRawdata.LLM;
    ViconRLM_X = -ViconRawdata.RLM;
    XCOM_X = VRRawdata.XCoM_PosX;
    
    %% Flip Vicon
    if ismember(Trials,FlipTrials)
        Viconvert = ViconRawdata.Var19;
    else
        Viconvert = ViconRawdata.Var16;
    end
    
    %% Syncing Process
    if abs(length(VRTime)-length(ViconTime))>200
        DTimeindex = round(linspace(1,length(VRTime),length(ViconTime)));
        DTime = VRTime(DTimeindex);
    else
      if length(VRTime)-length(ViconTime)>0
          DTimeindex = 1:length(ViconTime);
          DTime = VRTime(DTimeindex);
      else
          DTimeindex = 1:length(VRTime);
          DTime = VRTime;
          Viconvert = Viconvert(DTimeindex);
          ViconTime = ViconTime(DTimeindex);
      end
    end
    ViconLLM_X = ViconLLM_X(ViconTime);
    ViconRLM_X = ViconRLM_X(ViconTime);
    DXCOM_X = XCOM_X(DTimeindex);
    
    VRLLMvert = VRRawdata.LLMvert*1000;
    DVRLLMvert = VRLLMvert(DTimeindex);
    
    % lag beteween second peaks VR-Vicon
    [DVRLLMvertmax,DVRLLMvertmaxindex] = max(DVRLLMvert);
    DVRLLMvertmaxindex = islocalmax(DVRLLMvert,'MinSeparation',200,'SamplePoints',DTime);
    DVRLLMvertmax = DVRLLMvert(DVRLLMvertmaxindex);
    DVRLLMvertmaxtime = DTime(DVRLLMvertmaxindex);
    SecondMaxPeak = DVRLLMvertmax(2);
    SecondMaxPeakTime = DVRLLMvertmaxtime(2);
    SecondMaxPeakTimeIndex = round(SecondMaxPeakTime);
    % Find corresponding peak within the window
    SecondMaxPeakTimeWindow = [SecondMaxPeakTimeIndex-80:SecondMaxPeakTimeIndex+80];
    SecondMaxPeakSync = max(Viconvert(SecondMaxPeakTimeWindow));
    SecondMaxPeakSyncTimeIndex = find(Viconvert==SecondMaxPeakSync);
    % Time lag is VR-Vicon
    SyncTimeLag = SecondMaxPeakTimeIndex-SecondMaxPeakSyncTimeIndex;
    
    figure
    plot(DTime,DVRLLMvert);
    hold on
    plot(ViconTime,Viconvert)
%     hold on
%     plot(SecondMaxPeakTime,SecondMaxPeak,'*')
    title('Before Syncing')
    legend('VR Data','Vicon Data','SecondMaxPeak')
    
    if SyncTimeLag>0
        DTime(end-SyncTimeLag+1:end)=[];
        DVRLLMvert([1:SyncTimeLag])=[];
        DXCOM_X([1:SyncTimeLag])=[];
        ViconTime(end-SyncTimeLag+1:end)=[];
        Viconvert(end-SyncTimeLag+1:end)=[];
        ViconLLM_X(end-SyncTimeLag+1:end)=[];
        ViconRLM_X(end-SyncTimeLag+1:end)=[];
    else
        ViconTime(end+SyncTimeLag+1:end)=[];
        Viconvert([1:-SyncTimeLag])=[];
        ViconLLM_X(end+SyncTimeLag+1:end)=[];
        ViconRLM_X(end+SyncTimeLag+1:end)=[];
        DTime(end+SyncTimeLag+1:end)=[];
        DVRLLMvert(end+SyncTimeLag+1:end)=[];
        DXCOM_X(end+SyncTimeLag+1:end)=[];
    end
    
    [vertmax,t_Max,t_Min,vertmin] = DataProcessor(Viconvert,ViconTime);
    
    figure
    plot(DTime,DVRLLMvert);
    hold on
    plot(ViconTime,Viconvert)
    hold on
%     plot(t_Max,vertmax,'*',t_Min,vertmin,'*')
    title('After Syncing')
    legend('VR Data','Vicon Data')
    
    figure
    subplot(3,1,1)
    plot(ViconTime,ViconLLM_X)
    subplot(3,1,2)
    plot(ViconTime,ViconRLM_X)
    subplot(3,1,3)
    plot(ViconTime,DXCOM_X)
    
    %% Cross Correlation
    Windowsize = max(diff(t_Max));
%     ratio = 1/10; % Set a ratio here This ratio is based on 6000 lag points
    
    % Left leg Time lag of VR-Vicon (crosscorr)
    [LLMxcf,LLMlags,LLMbounds] = crosscorr(ViconLLM_X,DXCOM_X,length(DXCOM_X)-1);
    LLMxcfpartial = LLMxcf(end/2-Windowsize:end/2+Windowsize);
    LLMlagspartial = LLMlags(end/2-Windowsize:end/2+Windowsize);
    [LLMMaxxcfabs,LLMmaxxcfindex] = max(abs(LLMxcfpartial));
    LLMmaxxcflag = LLMlagspartial(LLMmaxxcfindex);
    LLMMaxxcf(Trials) = LLMxcfpartial(LLMmaxxcfindex);
    LLMmaxxcflagtime(Trials) = (DTime(end)-DTime(1))*LLMmaxxcflag/length(ViconTime)/100; % need to be fixed
    
    % Right leg Time lag of VR-Vicon (crosscorr)
    [RLMxcf,RLMlags,RLMbounds] = crosscorr(ViconRLM_X,DXCOM_X,length(DXCOM_X)-1);
    RLMxcfpartial = RLMxcf(end/2-Windowsize:end/2+Windowsize);
    RLMlagspartial = RLMlags(end/2-Windowsize:end/2+Windowsize);
    [RLMMaxxcfabs,RLMmaxxcfindex] = max(abs(RLMxcfpartial));
    RLMmaxxcflag = RLMlagspartial(RLMmaxxcfindex);
    RLMMaxxcf(Trials) = RLMxcfpartial(RLMmaxxcfindex);
    RLMmaxxcflagtime(Trials) = DTime(end)*RLMmaxxcflag/length(ViconTime)/100;
    
    % Time lag of VR-Vicon (Sync by Second Peak)
    SyncTimeLagConvert(Trials) = SyncTimeLag/length(DTime)*VRTime(end)/100;
    
    figure
    subplot(2,1,1)
    crosscorr(ViconLLM_X,DXCOM_X,length(ViconTime)-1)
    hold on
    maxccfplot = plot(LLMmaxxcflag,LLMMaxxcf(Trials),'b*');
    legend(maxccfplot,'Max CCF')
    title('Left Leg CCF Vs. Time Lag')
    subplot(2,1,2)
    crosscorr(ViconRLM_X,DXCOM_X,length(ViconTime)-1)
    hold on
    maxccfplot = plot(RLMmaxxcflag,RLMMaxxcf(Trials),'b*');
    legend(maxccfplot,'Max CCF')
    title('Right Leg CCF Vs. Time Lag')
    saveas(gcf,[pwd,sprintf('./DataPackage/Figures/%s Cross Correlation Vs. lag.png',ViconTablename(Trials))],'png')
    
    fprintf('%s has Left leg CCF %2.3f with time lag %3.3fs\n',ViconTablename(Trials),LLMMaxxcf(Trials),LLMmaxxcflagtime(Trials))
    fprintf('%s has Right leg CCF %2.3f with time lag %3.3fs\n',ViconTablename(Trials),RLMMaxxcf(Trials),RLMmaxxcflagtime(Trials))
end

diary off

figure
plot(1:Trials,LLMMaxxcf,'-o',1:Trials,RLMMaxxcf,'-o')
xticks(0:1:Trials+1)
xlim([0 Trials+1])
grid on
legend('Left Leg','Right Leg')
title('Cross Correlation Function Vs. Trial numbers')
xlabel('Trial Numbers (Not Actual Trial Number)')
ylabel('Cross Correlation Function')
saveas(gcf,[pwd,sprintf('./DataPackage/Figures/Overall Cross Correlation Vs. lag.png')],'png')

exportfile = strcat('DataPackage/',Sessionnumber,'DataTable','.xlsx');
xlswrite(exportfile,["LLMCCF","LLM Time Lag","RLMCCF","RLM Time Lag"],'Sheet1','A1')
xlswrite(exportfile,[LLMMaxxcf' LLMmaxxcflagtime' RLMMaxxcf' RLMmaxxcflagtime'],'Sheet1','A2')

movefile('DataPackage',strcat(Sessionnumber,'DataPackage')) % Rename the Package

function [vertmax,t_Max,t_Min,vertmin] = DataProcessor(Rawdata,frames)
    vertmax_index = islocalmax(Rawdata,'MinSeparation',120,'SamplePoints',frames);
    vertmin_index = islocalmin(Rawdata,'MinSeparation',120,'SamplePoints',frames);
    % Eliminate repeating min values and time frames
    t_Min = unique(frames(vertmin_index));
    vertmin = unique(Rawdata(vertmin_index));
    t_Max = frames(vertmax_index);
    vertmax = Rawdata(vertmax_index);

    %% Eliminate the first max data if max goes first
    First = find(t_Max<t_Min(1));
    t_Max(First) = [];
    vertmax(First) = [];

    %% If multiple mins between maxs, eliminate them and leave the last one
    if max(t_Max)<max(t_Min)
        t_Minnew = [];
        for p = 1:length(t_Max)
            minindex = find(t_Min>t_Max(p),1);
            t_Minnew(p) = t_Min(minindex-1);
        end
        t_Min = t_Minnew;
        vertmin = Rawdata(t_Min);
    elseif max(t_Max)>max(t_Min)
        t_Minnew = [];
        for p = 1:length(t_Max)-1
            minindex = find(t_Min>t_Max(p),1);
            t_Minnew(p) = t_Min(minindex-1);
        end
        t_Min = [t_Minnew t_Min(minindex)];
        vertmin = Rawdata(t_Min);
    end
    t_Min = unique(t_Min,'stable');
    vertmin = unique(vertmin,'stable');

    %% If multiple maxs, eliminate them and leave the last one
    for maxindex = 1:length(t_Min)
        if t_Min(maxindex)>t_Max(maxindex)
            t_Max(maxindex) = [];
            vertmax(maxindex) = [];
        end
    end

    %% Find length difference and elinminate extra Max
    if length(vertmax)-length(vertmin) > 0
        vertmax = vertmax(1:end-1);
        t_Max = t_Max(1:end-1);
    end
    
    t_Min = t_Min';
end