

%此脚本在做完ICA，去除眼电等成分后，进行第二次分段
%分段时会按照不同的mark存成不同的文件，分段的的长度为-0.2——1.0，按照需要修改
clc;clear;close all;
%%
root_dir='G:\实验2\脑电数据\cleaned_new';
out_dir='G:\实验2\脑电数据\average';
cd(root_dir)
data_list=dir('*.set');
%%
[ALLEEG,EEG,CURRENTSET,ALLCOM] = eeglab; %starts EEGLAB
for j=1:length(data_list)
    %% 设定参数
    % reject criteria
    Upper_Limit = 80;
    Lower_Limit = -80;
    
    if ~exist (out_dir,'file')
        mkdir(out_dir);
    end
    
    % Baseline Parameters
    Baseline_cue = [-200 0];% in timepoints  matrix 
    Epoch_Start = -0.20;% in seconds
    Epoch_End = 1.00;     % in seconds
    mark = {'S 11','S 12','S 13','S 14','S 21','S 22','S 23','S 24'};
    %%
    for m=1:length(mark)
        
        EEG = pop_loadset('filename',data_list(j).name,'filepath',root_dir);
        EEG = eeg_checkset( EEG );
        
        %二次分段
        EEG = pop_epoch( EEG,mark(m), [Epoch_Start Epoch_End], 'newname', [data_list(j).name(1:3),'_epochs'], 'epochinfo', 'yes');
        % baseline correction
        EEG = pop_rmbase( EEG, Baseline_cue );
        EEG = eeg_checkset( EEG );
        % remove artifaction
        A=EEG.nbchan;
        [EEG,Indexes] = pop_eegthresh(EEG, 1, 1:A, Lower_Limit, Upper_Limit, Epoch_Start, Epoch_End, 1, 0);  % reject artifacts by detecting outlier values，这一步是标记伪迹
        EEG = pop_rejepoch( EEG, Indexes, 0);%这一步去除刚刚标记的伪迹
        EEG = eeg_checkset( EEG );
        
        mark_folder = fullfile(out_dir,mark{m}(3:end));%mark是2位数，所以是3：end; mark是3位数 2：end;mark位数统一
        if ~exist (mark_folder,'file')%建立一个文件夹
            mkdir(mark_folder);
        end
        cd(mark_folder);%把分完段的数据保存在该文件夹下
        
        setname = [data_list(j).name(1:3),'_epoch_',mark{m}(3:end)];
        EEG = pop_saveset(EEG,'filename',setname,'filepath',mark_folder);
        EEG=[];
        cd(root_dir)
    end
end
