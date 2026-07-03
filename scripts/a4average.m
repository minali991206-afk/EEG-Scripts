%二次分段后数据进行叠加平均，将每个被试的所有trial平均为一个，避免维度不齐
%组间因素建议提前整理数据，在data_cond文件夹内建立两个组文件夹，在组文件夹内建立每个mark的文件夹
%具体请结合自己数据情况修改  by ZN
clc;clear;close all
root_dir='G:\实验2\脑电数据\average';%all of marks of epoch
out_dir='G:\实验2\脑电数据\average\';
mark_dir={'11','12','13','14','21','22','23','24'};%name of the marks files
cd(root_dir)
[ALLEEG,EEG,CURRENTSET,ALLCOM] = eeglab;
%% 组内
for condi=1:length(mark_dir) %每个条件
    markfile=fullfile(root_dir,mark_dir{condi});
    cd(markfile)
    datalist=dir('*.set');
    for i=1:length(datalist)%每个被试 i=[1 3:6 8:length(datalist)]去除trial数少的被试时用，例如去除2和7
        EEG=pop_loadset(datalist(i).name);
        EEG = eeg_checkset(EEG);
        num_trials(i)=size(EEG.data,3);%3是对应的数trial数
        data(:,:,i)=squeeze(mean(EEG.data,3));%channels*tmps*subject
    end
    total_num_trial(:,condi) = num_trials; %subject*cond
    total_data(:,:,:,condi)=data;%channels*tmps*subject*cond
end
% %% 组间
% % group_dir={'g1','g2'};
% % for group=1:2 %每个组
%     groupfile=fullfile(root_dir,group_dir{group});
%     cd(groupfile)
%     for condi=1:length(mark_dir)  %每个条件
%         markfile=fullfile(groupfile,mark_dir{condi});
%         cd(markfile)
%         datalist=dir('*.set');
%         for i=1:length(datalist) %每个被试
%             EEG=pop_loadset(datalist(i).name);
%             EEG = eeg_checkset(EEG);
%             num_trials(i)=size(EEG.data,3);
%             data(:,:,i)=squeeze(mean(EEG.data,3));%channels*tmps*subject
%         end
%         group_num_trial(:,condi)=num_trials;%subject*cond
%         groupdata(:,:,:,condi)=data;%channels*tmps*subject*cond
%     end
%     total_num_trial(:,group) = group_num_trial; %subject*cond*group
%     total_data(:,:,:,group)=groupdata;%channels*tmps*subject*cond*group
% end
%% 存储数据
if ~exist (out_dir,'file')
    mkdir(out_dir);
end
cd(out_dir)
EEG_chanlocs = EEG.chanlocs;
EEG_times = EEG.times;
save total_data.mat total_data
save total_num_trial.mat total_num_trial %看每个条件下每个被试剩余的trials 如果被试单个trial数太少，可以直接在二次分段后的文件夹内删除被试也可以用代码，在上
save('EEG_times.mat','EEG_times')
save('EEG_chanlocs.mat','EEG_chanlocs')