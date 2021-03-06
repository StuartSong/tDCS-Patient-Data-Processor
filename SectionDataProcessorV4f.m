% This is for fast walking subject with more than sufficient steps
% Information needs to be manually entered:
% Max or Min minibatch

clear
close all
clc

%% Session number
currentFolder = pwd;
[filepath,Sessionnumber] = fileparts(currentFolder);

%% Import Data and Create Folder
Names = dir('**/*.csv');
Tablenames = {Names.name};
mkdir DataPackage;
mkdir DataPackage\Figures;
Tname = string(Tablenames);
Tablename = erase(Tname,'.csv');

%% Record the Command Window
diary(strcat('./DataPackage/','Readme.txt'))

%% Manually set minibatches for both max and min scan
Minibatch = 95

%% Loop for the section
for Trials = 1:length(Tablenames)
    fprintf('Processing %s\n',Tablename(Trials))
    Rawdata = readtable(Tname(Trials));

    %% Create Time Vector
    frames = 1:length(Rawdata.('RLM'))-1;

    %% Left Lateral Malleolus
    Rawdata_LLM = Rawdata.('LLM');
    LLM_X = str2double(Rawdata_LLM(2:end))';

    %% Right Lateral Malleolus
    Rawdata_RLM = Rawdata.('RLM');
    % Flip negative displacement values to positive
    RLM_X = abs(str2double(Rawdata_RLM(2:end))');
    RLM_X_Max_index = islocalmax(RLM_X,'MinSeparation',Minibatch,'SamplePoints',frames);
    RLM_X_Min_index = islocalmin(RLM_X,'MinSeparation',Minibatch,'SamplePoints',frames);
    % Eliminate repeating min values and time frames
    t_Min = unique(frames(RLM_X_Min_index));
    RLM_X_Min = unique(RLM_X(RLM_X_Min_index));
    t_Max = frames(RLM_X_Max_index);
    RLM_X_Max = RLM_X(RLM_X_Max_index);

    %% Eliminate the first max data if max goes first
    First = find(t_Max<t_Min(1));
    t_Max(First) = [];
    RLM_X_Max(First) = [];

    %% If multiple mins between maxs, eliminate them and leave the last one
    if max(t_Max)<max(t_Min)
        t_Minnew = [];
        for p = 1:length(t_Max)
            minindex = find(t_Min>t_Max(p),1);
            t_Minnew(p) = t_Min(minindex-1);
        end
        t_Min = t_Minnew;
        RLM_X_Min = RLM_X(t_Min);
    elseif max(t_Max)>max(t_Min)
        t_Minnew = [];
        for p = 1:length(t_Max)-1
            minindex = find(t_Min>t_Max(p),1);
            t_Minnew(p) = t_Min(minindex-1);
        end
        t_Min = [t_Minnew t_Min(minindex)];
        RLM_X_Min = RLM_X(t_Min);
    end
    t_Min = unique(t_Min,'stable');
    RLM_X_Min = unique(RLM_X_Min,'stable');

    %% If multiple maxs between mins, eliminate them and leave the last one
    for maxindex = 1:length(t_Min)
        if t_Min(maxindex)>t_Max(maxindex)
            t_Max(maxindex) = [];
            RLM_X_Max(maxindex) = [];
            fprintf('step% d max has been eliminated\n',maxindex)
        end
    end

    %% Find length difference and elinminate extra Max
    if length(RLM_X_Max)-length(RLM_X_Min) > 0
        RLM_X_Max = RLM_X_Max(1:end-1);
        t_Max = t_Max(1:end-1);
    end
    Displacement{Trials} = RLM_X_Max-RLM_X_Min;
    
    %% Eliminate the outlier
    Outlier = find(Displacement{Trials}<=20);
    t_Max(Outlier) = [];
    RLM_X_Max(Outlier) = [];
    t_Min(Outlier) = [];
    RLM_X_Min(Outlier) = [];
    Displacement{Trials} = RLM_X_Max-RLM_X_Min;
    Dis_Mean{Trials} = mean(Displacement{Trials});
    Dis_Std{Trials} = std(Displacement{Trials});

    %% Plot coordinates vs. Frames
    figure
    plot(t_Max,RLM_X_Max,'b*')
    hold on
    plot(t_Min,RLM_X_Min,'r*')
    hold on
    plot(frames,RLM_X)
    legend('Local Maxima','Local Minima')
    title(sprintf('%s RLM x-coordinate Vs. Frames',Tablename(Trials)))
    xlabel('Number of Frames')
    ylabel('x-coordinate (mm)')
    grid on
    saveas(gcf,[pwd,sprintf('./DataPackage/Figures/%s RLM x-coordinate Vs. Frames.png',Tablename(Trials))],'png')
end

    %% X-axis Displacement
    Dis_Cell = Displacement;
    Dis_Mean = cell2mat(Dis_Mean); % Average
    Dis_Std = cell2mat(Dis_Std); % Standard Deviation
    Displacement = cell2mat(Displacement);
    Diff_STD = std(Displacement);
    Diff_Mean = mean(Displacement);

    %% Plot Displacement
    figure
    histogram(Displacement)
    title('Histogram of Horizontal Displacement')
    xlabel('Horizontal Displacement (mm)')
    ylabel('Number of appearance')
    saveas(gcf,[pwd,sprintf('./DataPackage/Figures/%s Histogram Horizontal Displacement Vs. Frames.png',Sessionnumber)],'png')

    %% Plot Average and Errorbar for each Trial
    figure
    bar([2:length(Tablename)+1],Dis_Mean)
    hold on
    eb = errorbar([2:length(Tablename)+1],Dis_Mean,Dis_Std,'.');
    eb.Color = 'k';
    grid on
    xlabel('Trial Number')
    ylabel('Average x-diaplacement (mm)')
    title('Average x-diaplacement vs. Trial Number')
    saveas(gcf,[pwd,sprintf('./DataPackage/Figures/%s Average x-diaplacement vs. Trial Number.png',Sessionnumber)],'png')

    %% Create Data Table
    MLD_Array = Dis_Cell{1}';
    Step_Array = [1:length(Dis_Cell{1})]';
    Trial_Array = repmat(Tablename(1),length(Dis_Cell{1}),1);
    Session_Array = repmat(Sessionnumber,length(Dis_Cell{1}),1);
    tab = 0;
    while tab < Trials-1
        tab = tab+1;
        MLD_Array = [MLD_Array; Dis_Cell{tab+1}'];
        Step_Array = [Step_Array;[1:length(Dis_Cell{tab+1})]'];
        Trial_Array = [Trial_Array;repmat(Tablename(tab+1),length(Dis_Cell{tab+1}),1)];
        Session_Array = [Session_Array;repmat(Sessionnumber,length(Dis_Cell{tab+1}),1)];
    end

    diary off % End Recording the Command Window
    exportfile = strcat('DataPackage/','MB',num2str(Minibatch),Sessionnumber,'DataTable','.xlsx');
    xlswrite(exportfile,[Session_Array,Trial_Array,Step_Array,MLD_Array],'Sheet1','A2')
    xlswrite(exportfile,["Session","Trial","Step","ML_Displacement"],'Sheet1','A1')

    movefile('DataPackage',strcat(Sessionnumber,'DataPackage')) % Rename the Package