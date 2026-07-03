%预处理脚本，所用数据为BP所记录的数据
%采样率为1kHz，64通道，Gnd位置为AFz，REF为FCz，眼电为IO
%第一次分段，基于刺激呈现mark进行，最终划分时长为[-500ms 1500ms]
%处理后数据进入【去除坏段】阶段  by ZN
clc;clear;close all;
%% 设定数据读取和存储路径 & 打开EEGLAB
root_dir= 'D:\data\脑电数据\A_eegdata';     %创建root_dir变量并赋值为原始数据存储的目录
out_dir = 'D:\data\脑电数据\B_pre_epoch';%创建out_dir变量并赋值为预处理后数据存储的目录

cd(root_dir)                %cd函数更改当前目录，改为原始数据存储的目录
data_list = dir('*.vhdr');  %创建data_list变量，读取当前文件夹内指定类型的文件

[ALLEEG,EEG,CURRENTSET,ALLCOM] = eeglab; %starts EEGLAB
%在循环外打开eeglab，可避免反复开启界面，但可能增加虚拟内存需求(?)
%%  开始预处理
for k=1:length(data_list) %length函数输出data_list变量的中.vhdr文件的数量，然后是一个for循环读取每一个文件
    EEG = pop_loadbv(root_dir, data_list(k).name, [], []);%载入.vhdr文件用pop_loadbv函数EEG = pop_loadbv(root_dir, data_list(k).name, [], [])
    EEG = eeg_checkset( EEG );
    
    % channal location
    EEG=pop_chanedit(EEG, 'lookup','E:\matlab\eeglab2022.0\eeglab2022.0\plugins\dipfit\standard_BESA\standard-10-5-cap385.elp');
    EEG = eeg_checkset( EEG );
    
    %恢复FCz的label并插值获取FCz数据（替代IO，确认IO位置，不同帽子数字不同）将第一个人手动channal location再看IO的位置FCZ代替IO
    EEG=pop_chanedit(EEG, 'changefield',{20 'labels' 'FCz'},'lookup','E:\matlab\eeglab2022.0\eeglab2022.0\plugins\dipfit\standard_BESA\standard-10-5-cap385.elp');
    EEG.data(20,:,:) = mean(EEG.data([17 18 21 22],:,:));
    EEG = eeg_checkset( EEG );
    
    
    %插值坏导 %视被试数据情况而定，需结合实验中情况记录判断
%     EEG.data(2,:,:) = mean(EEG.data([36 50 57],:,:));
%     EEG.data(35,:,:) = mean(EEG.data([1 3 29 49],:,:));
%     EEG.data(1,:,:) = mean(EEG.data([35 49 57],:,:));
%     EEG.data(50,:,:) = mean(EEG.data([2 12 36 44],:,:));
%     EEG.data(13,:,:) = mean(EEG.data([45 51 53],:,:));
%     EEG.data(14,:,:) = mean(EEG.data([46 52 54],:,:));
    
    %去除电极
    %一般情况下这四个电极数据噪音较大，且不纳入分析，可删
    %若要进行双极参考而非全脑平均，此步骤可与下一步交换顺序
    EEG = pop_select( EEG,'nochannel',{'FT9' 'TP9' 'FT10' 'TP10'});
    EEG = eeg_checkset( EEG );
    
    %重参考 全脑平均
    EEG = pop_reref( EEG, []);
%     %重参考 双极参考
%     EEG = pop_reref( EEG,[31 32]/{'TP9','TP10'});
    EEG = eeg_checkset( EEG );
    
    %filter
    EEG = pop_eegfiltnew(EEG, [], 0.1, 16500, true, [], 1);%高通滤波0.1Hz
    EEG = eeg_checkset( EEG );
    EEG = pop_eegfiltnew(EEG, [], 30, 220, 0, [], 1);%低通滤波30Hz
    EEG = eeg_checkset( EEG );
    EEG = pop_eegfiltnew(EEG, 'locutoff',48,'hicutoff',52,'revfilt',1);%陷波滤波48-52Hz
    EEG = eeg_checkset( EEG );
    
    %基于刺激mark进行分段，被试编号a位数则是data_list(k).name(1:a)
    EEG = pop_epoch( EEG, {'S 11','S 12','S 13','S 14','S 21','S 22','S 23','S 24'}, [-0.5  1.5], 'newname', [ data_list(k).name(1:3),'_epochs'], 'epochinfo', 'yes');%newname输入新名字 001 1:3 
    EEG = eeg_checkset( EEG );%mark长度固定是4位，s是第一位，一位数的话s与mark之间两个空格，两位数是一个空格，三位数无空格
    
    %判断处理后数据存储路径是否存在，不存在将创建相应文件夹
    if ~exist (out_dir,'file')
        mkdir(out_dir);
    end
    
    %定位到存储路径，并存储数据，命名要求和分段时一致
    cd(out_dir)
    EEG = pop_saveset( EEG, 'filename',[data_list(k).name(1:3),'.set'],'filepath',out_dir);
    EEG = eeg_checkset( EEG );
    
    %重新定位至原始数据路径，开始下一个.vhdr文件的处理
    cd(root_dir)
    EEG=[];
end