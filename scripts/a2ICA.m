%此脚本为进行ICA处理脚本，建议在去除坏段后进行
clc;clear;close all ;
%% 设定路径，读取数据
root_dir = 'D:\运动想象数据\0405\raw_data\selection2_noICA_zhangdingning8-30';
out_dir  = 'D:\运动想象数据\0405\raw_data\ICA';
cd(root_dir)
data_list=dir('*.set');
%% 打开eeglab，开始ICA
[ALLEEG,EEG,CURRENTSET,ALLCOM] = eeglab; %starts EEGLAB
for k=1:length(data_list)
    
    EEG = pop_loadset('filename',data_list(k).name,'filepath',root_dir);%load dataest
    EEG = eeg_checkset( EEG );
    
    %降采样
%     EEG=pop_resample(EEG,500);%将数据进行降采样，此处降至500Hz
    EEG = eeg_checkset( EEG );
    
    EEG = pop_runica(EEG, 'extended',1,'pca',30,'interupt','on');
    EEG = eeg_checkset( EEG );
    
    if ~exist (out_dir,'file')
        mkdir(out_dir);
    end
    
    cd(out_dir)
    setname = strcat(data_list(k).name(1:3),'_ica.set');
    EEG = pop_saveset( EEG, 'filename',setname,'filepath',out_dir);
    EEG = eeg_checkset( EEG );
    EEG=[];
    cd(root_dir)
end