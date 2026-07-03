%% ==================== 配置参数 ====================
clear; clc;

data_root = '   ';
out_dir   = '   ';
elec_file = 'E:\matlab\eeglab2022.0\eeglab2022.0\plugins\dipfit\standard_BESA\standard-10-5-cap385.elp';

subject_ids = {'001','002','003','004','005','006','007','008', '009', '010'...
               '011','012', '013', '014','015','016','017','018','019','020','021','022','023','024','025','026','027','028','029','030', '031', '032'};

% 条件编码：
% c=1: 'S 11' crowd-angry-direct   c=2: 'S 12' crowd-angry-averted
% c=3: 'S 13' crowd-fearful-direct   c=4: 'S 14' crowd-fearful-averted
% c=5: 'S 21' single-angry-direct   c=6: 'S 22' single-angry-averted
% c=7: 'S 23' single-fearful-direct   c=8: 'S 24' single-fearful-averted
markers = {'S 11','S 12','S 13','S 14','S 21','S 22','S 23','S 24'};

num_permutations = 2000;
cluster_alpha    = 0.05;
stat_alpha       = 0.05;
latency_limits   = [0, 1];    % 秒，全时程不预设窗口
time_range_ms    = [0, 1000]; % 仅用于可视化

if ~exist(out_dir, 'dir'); mkdir(out_dir); end

bin_size_ms = 10;  % 时间分箱宽度（ms）

%% ==================== 获取电极标签 ====================
set_files = dir(fullfile(data_root, '*_epoch.set'));
if isempty(set_files)
    error('在 %s 中没有找到 .set 文件', data_root);
end
EEG_example   = pop_loadset('filename', set_files(1).name, 'filepath', set_files(1).folder);
actual_labels = {EEG_example.chanlocs.labels};
n_chan = length(actual_labels);
fprintf('电极数量: %d\n', n_chan);

%% ==================== 构建电极结构 ====================
if ~exist(elec_file, 'file')
    error('电极模板文件不存在: %s', elec_file);
end
try
    elec_full = ft_read_sens(elec_file, 'fileformat', 'besa_elp');
catch
    fid = fopen(elec_file, 'r');
    C   = textscan(fid, '%s %f %f %f', 'CommentStyle', '%');
    fclose(fid);
    elec_full.label   = C{1};
    elec_full.chanpos = [C{2}, C{3}, C{4}];
    elec_full.elecpos = [C{2}, C{3}, C{4}];
    elec_full.unit    = 'mm';
end
idx = zeros(1, n_chan);
for i = 1:n_chan
    f = find(strcmpi(elec_full.label, actual_labels{i}));
    if isempty(f); error('电极 %s 未在模板中找到', actual_labels{i}); end
    idx(i) = f(1);
end
elec.label   = actual_labels;
elec.chanpos = elec_full.chanpos(idx, :);
elec.elecpos = elec_full.elecpos(idx, :);
elec.unit    = elec_full.unit;

%% ==================== 读取数据：单被试 × 单条件 ERP ====================
%
% timelock_all{s, c}：第 s 个被试在第 c 个条件下的 ft_timelockanalysis
% 输出（keeptrials='no'），即单被试条件均值，是 depsamplesT 的正确输入单元。
%
n_sub  = length(subject_ids);
n_cond = length(markers);
timelock_all = cell(n_sub, n_cond);

fprintf('读取 %d 被试 × %d 条件...\n', n_sub, n_cond);
for s = 1:n_sub
    subj_id   = subject_ids{s};
    file_name = [subj_id '_epoch.set'];
    if ~exist(fullfile(data_root, file_name), 'file')
        error('文件不存在: %s', fullfile(data_root, file_name));
    end
    EEG     = pop_loadset('filename', file_name, 'filepath', data_root);
    data_ft = eeglab2fieldtrip(EEG, 'preprocessing', 'none');

    for c = 1:n_cond
        marker = markers{c};   % 字符串，例如 'S 11'

        % 从 EEG.epoch 中找对应 epoch 序号（与 data_ft.trial 索引一致）
        % EEG.epoch(ep).eventtype 可能是单个字符串或 cell 数组（同一 epoch
        % 内有多个事件时），统一转成 cell 后做字符串精确匹配。
        epoch_idx = [];
        for ep = 1:length(EEG.epoch)
            ep_types = EEG.epoch(ep).eventtype;
            if ~iscell(ep_types); ep_types = {ep_types}; end
            % 数值型 type 转字符串（兼容不同 EEGLAB 版本）
            if isnumeric(ep_types{1})
                ep_types = cellfun(@(x) sprintf('S%3d', x), ep_types, 'UniformOutput', false);
            end
            if any(strcmp(ep_types, marker))
                epoch_idx(end+1) = ep; %#ok<SAGROW>
            end
        end
        if isempty(epoch_idx)
            error('条件 "%s" 在被试 %s 中未找到，请确认 EEG.epoch.eventtype 的格式', ...
                  marker, subj_id);
        end

        cfg_avg            = [];
        cfg_avg.keeptrials = 'no';
        cfg_avg.trials     = epoch_idx;
        timelock_all{s, c} = ft_timelockanalysis(cfg_avg, data_ft);
    end
    fprintf('  被试 %s 完成\n', subj_id);
end
fprintf('数据读取完成。\n');

%% ==================== 时间分箱 ====================
fprintf('时间分箱 (%d ms/bin)...\n', bin_size_ms);
for s = 1:n_sub
    for c = 1:n_cond
        timelock_all{s,c} = bin_timelock(timelock_all{s,c}, bin_size_ms);
    end
end

% 一致性检查
ref = timelock_all{1,1};
for s = 1:n_sub
    for c = 1:n_cond
        if ~isequal(timelock_all{s,c}.time,  ref.time)  || ...
           ~isequal(timelock_all{s,c}.label, ref.label)
            error('时间轴或通道标签不一致：被试 %d 条件 %d', s, c);
        end
    end
end
fprintf('一致性检查通过。\n');

%% ==================== 邻居结构 ====================
cfg_nb          = [];
cfg_nb.elec     = elec;
cfg_nb.method   = 'triangulation';
cfg_nb.feedback = 'yes';
neighbours      = ft_prepare_neighbours(cfg_nb);
save(fullfile(out_dir, 'neighbours.mat'), 'neighbours');
fprintf('邻居构建完成，平均邻居数: %.1f\n', ...
    mean(cellfun(@numel, {neighbours.neighblabel})));

%% ==================== 主效应 1：群体大小 ====================
fprintf('\n=== 1. 群体大小主效应 (Crowd vs Single) ===\n');
crowd_avg  = cell(1, n_sub);
single_avg = cell(1, n_sub);
for s = 1:n_sub
    crowd_avg{s}  = average_conditions(timelock_all(s, [1,2,3,4]));
    single_avg{s} = average_conditions(timelock_all(s, [5,6,7,8]));
end
stat_crowd = run_paired_cluster_test(crowd_avg, single_avg, neighbours, ...
    num_permutations, cluster_alpha, stat_alpha, latency_limits);
save(fullfile(out_dir, 'stat_crowd_vs_single.mat'), 'stat_crowd');
export_clusters_to_excel(stat_crowd, fullfile(out_dir, 'stat_crowd_vs_single.xlsx'));
plot_clusters(stat_crowd, actual_labels, time_range_ms, ...
    fullfile(out_dir, 'Fig_crowd_vs_single.png'), '群体大小主效应 (Crowd vs Single)');

%% ==================== 主效应 2：情绪 ====================
fprintf('\n=== 2. 情绪主效应 (Fear vs Anger) ===\n');
fear_avg  = cell(1, n_sub);
anger_avg = cell(1, n_sub);
for s = 1:n_sub
    fear_avg{s}  = average_conditions(timelock_all(s, [3,4,7,8]));
    anger_avg{s} = average_conditions(timelock_all(s, [1,2,5,6]));
end
stat_emotion = run_paired_cluster_test(fear_avg, anger_avg, neighbours, ...
    num_permutations, cluster_alpha, stat_alpha, latency_limits);
save(fullfile(out_dir, 'stat_emotion.mat'), 'stat_emotion');
export_clusters_to_excel(stat_emotion, fullfile(out_dir, 'stat_emotion.xlsx'));
plot_clusters(stat_emotion, actual_labels, time_range_ms, ...
    fullfile(out_dir, 'Fig_emotion.png'), '情绪主效应 (Fear vs Anger)');

%% ==================== 主效应 3：注视方向 ====================
fprintf('\n=== 3. 注视方向主效应 (Averted vs Direct) ===\n');
averted_avg = cell(1, n_sub);
direct_avg  = cell(1, n_sub);
for s = 1:n_sub
    averted_avg{s} = average_conditions(timelock_all(s, [2,4,6,8]));
    direct_avg{s}  = average_conditions(timelock_all(s, [1,3,5,7]));
end
stat_gaze = run_paired_cluster_test(averted_avg, direct_avg, neighbours, ...
    num_permutations, cluster_alpha, stat_alpha, latency_limits);
save(fullfile(out_dir, 'stat_gaze.mat'), 'stat_gaze');
export_clusters_to_excel(stat_gaze, fullfile(out_dir, 'stat_gaze.xlsx'));
plot_clusters(stat_gaze, actual_labels, time_range_ms, ...
    fullfile(out_dir, 'Fig_gaze.png'), '注视方向主效应 (Averted vs Direct)');

%% ==================== 交互效应：情绪 × 注视方向 ====================
%
% 每个被试先把群体因素平均掉，得到 2（情绪）× 2（注视）四个单元，
% 再计算交互差值 = (恐惧偏视 - 恐惧直视) - (愤怒偏视 - 愤怒直视)，
% 最后对差值做单样本聚类置换检验（vs 0）。
%
fprintf('\n=== 4. 情绪 × 注视方向交互效应 ===\n');

% 四个单元：跨群体平均
fear_ave_cell  = cell(1, n_sub);   % 恐惧-偏视
fear_dir_cell  = cell(1, n_sub);   % 恐惧-直视
anger_ave_cell = cell(1, n_sub);   % 愤怒-偏视
anger_dir_cell = cell(1, n_sub);   % 愤怒-直视
for s = 1:n_sub
    fear_ave_cell{s}  = average_conditions(timelock_all(s, [4, 8]));  % cond14+cond24
    fear_dir_cell{s}  = average_conditions(timelock_all(s, [3, 7]));  % cond13+cond23
    anger_ave_cell{s} = average_conditions(timelock_all(s, [2, 6]));  % cond12+cond22
    anger_dir_cell{s} = average_conditions(timelock_all(s, [1, 5]));  % cond11+cond21
end

% 交互差值
diff_emo_gaze = cell(1, n_sub);
for s = 1:n_sub
    diff_fear         = subtract_timelock(fear_ave_cell{s},  fear_dir_cell{s});
    diff_anger        = subtract_timelock(anger_ave_cell{s}, anger_dir_cell{s});
    diff_emo_gaze{s}  = subtract_timelock(diff_fear, diff_anger);
end

stat_emo_gaze = run_onesample_cluster_test(diff_emo_gaze, neighbours, ...
    num_permutations, cluster_alpha, stat_alpha, latency_limits);
save(fullfile(out_dir, 'stat_emotion_gaze_interaction.mat'), 'stat_emo_gaze');
export_clusters_to_excel(stat_emo_gaze, fullfile(out_dir, 'stat_emotion_gaze_interaction.xlsx'));
plot_clusters(stat_emo_gaze, actual_labels, time_range_ms, ...
    fullfile(out_dir, 'Fig_emotion_gaze_interaction.png'), '情绪 × 注视方向交互');

%% ==================== 简单效应：恐惧条件内注视方向 ====================
%
% 用上面已算好的 fear_ave_cell / fear_dir_cell（跨群体平均），
% 直接做配对聚类置换检验（偏视 vs 直视）。
%
fprintf('\n=== 5a. 简单效应：恐惧条件内注视方向 ===\n');
stat_fear_gaze = run_paired_cluster_test(fear_ave_cell, fear_dir_cell, neighbours, ...
    num_permutations, cluster_alpha, stat_alpha, latency_limits);
save(fullfile(out_dir, 'stat_fear_gaze.mat'), 'stat_fear_gaze');
export_clusters_to_excel(stat_fear_gaze, fullfile(out_dir, 'stat_fear_gaze.xlsx'));
plot_clusters(stat_fear_gaze, actual_labels, time_range_ms, ...
    fullfile(out_dir, 'Fig_fear_gaze.png'), '简单效应：恐惧条件内（偏视 vs 直视）');

%% ==================== 简单效应：愤怒条件内注视方向 ====================
fprintf('\n=== 5b. 简单效应：愤怒条件内注视方向 ===\n');
stat_anger_gaze = run_paired_cluster_test(anger_ave_cell, anger_dir_cell, neighbours, ...
    num_permutations, cluster_alpha, stat_alpha, latency_limits);
save(fullfile(out_dir, 'stat_anger_gaze.mat'), 'stat_anger_gaze');
export_clusters_to_excel(stat_anger_gaze, fullfile(out_dir, 'stat_anger_gaze.xlsx'));
plot_clusters(stat_anger_gaze, actual_labels, time_range_ms, ...
    fullfile(out_dir, 'Fig_anger_gaze.png'), '简单效应：愤怒条件内（偏视 vs 直视）');

%% ==================== 交互效应：群体 × 注视方向 ====================
fprintf('\n=== 6. 群体 × 注视方向交互效应 ===\n');
diff_size_gaze = cell(1, n_sub);
for s = 1:n_sub
    crowd_ave  = average_conditions(timelock_all(s, [2, 4]));
    crowd_dir  = average_conditions(timelock_all(s, [1, 3]));
    single_ave = average_conditions(timelock_all(s, [6, 8]));
    single_dir = average_conditions(timelock_all(s, [5, 7]));
    diff_size_gaze{s} = subtract_timelock( ...
        subtract_timelock(crowd_ave, crowd_dir), ...
        subtract_timelock(single_ave, single_dir));
end
stat_size_gaze = run_onesample_cluster_test(diff_size_gaze, neighbours, ...
    num_permutations, cluster_alpha, stat_alpha, latency_limits);
save(fullfile(out_dir, 'stat_size_gaze_interaction.mat'), 'stat_size_gaze');
export_clusters_to_excel(stat_size_gaze, fullfile(out_dir, 'stat_size_gaze_interaction.xlsx'));
plot_clusters(stat_size_gaze, actual_labels, time_range_ms, ...
    fullfile(out_dir, 'Fig_size_gaze_interaction.png'), '群体 × 注视方向交互');

%% ==================== 交互效应：群体 × 情绪 ====================
fprintf('\n=== 7. 群体 × 情绪交互效应 ===\n');
diff_size_emo = cell(1, n_sub);
for s = 1:n_sub
    crowd_fear   = average_conditions(timelock_all(s, [3, 4]));
    crowd_anger  = average_conditions(timelock_all(s, [1, 2]));
    single_fear  = average_conditions(timelock_all(s, [7, 8]));
    single_anger = average_conditions(timelock_all(s, [5, 6]));
    diff_size_emo{s} = subtract_timelock( ...
        subtract_timelock(crowd_fear,  crowd_anger), ...
        subtract_timelock(single_fear, single_anger));
end
stat_size_emo = run_onesample_cluster_test(diff_size_emo, neighbours, ...
    num_permutations, cluster_alpha, stat_alpha, latency_limits);
save(fullfile(out_dir, 'stat_size_emotion_interaction.mat'), 'stat_size_emo');
export_clusters_to_excel(stat_size_emo, fullfile(out_dir, 'stat_size_emotion_interaction.xlsx'));
plot_clusters(stat_size_emo, actual_labels, time_range_ms, ...
    fullfile(out_dir, 'Fig_size_emotion_interaction.png'), '群体 × 情绪交互');

%% ==================== 三阶交互：群体 × 情绪 × 注视方向 ====================
fprintf('\n=== 8. 三阶交互（群体 × 情绪 × 注视方向） ===\n');
three_way = cell(1, n_sub);
for s = 1:n_sub
    crowd_inter  = subtract_timelock( ...
        subtract_timelock(timelock_all{s,4}, timelock_all{s,3}), ...  % 群体恐惧: 偏-直
        subtract_timelock(timelock_all{s,2}, timelock_all{s,1}));     % 群体愤怒: 偏-直
    single_inter = subtract_timelock( ...
        subtract_timelock(timelock_all{s,8}, timelock_all{s,7}), ...  % 单个恐惧: 偏-直
        subtract_timelock(timelock_all{s,6}, timelock_all{s,5}));     % 单个愤怒: 偏-直
    three_way{s} = subtract_timelock(crowd_inter, single_inter);
end
stat_threeway = run_onesample_cluster_test(three_way, neighbours, ...
    num_permutations, cluster_alpha, stat_alpha, latency_limits);
save(fullfile(out_dir, 'stat_threeway_interaction.mat'), 'stat_threeway');
export_clusters_to_excel(stat_threeway, fullfile(out_dir, 'stat_threeway_interaction.xlsx'));
plot_clusters(stat_threeway, actual_labels, time_range_ms, ...
    fullfile(out_dir, 'Fig_threeway_interaction.png'), '三阶交互（群体×情绪×注视方向）');

fprintf('\n全部分析完成！结果保存至: %s\n', out_dir);

%% ======================================================================
%  辅助函数
%  ======================================================================

% -----------------------------------------------------------------------
% average_conditions
%   对同一被试的多个条件求 .avg 逐点均值，保持单被试 timelock 格式。
%   不能用 ft_timelockgrandaverage——那是跨被试总平均，会改变结构格式，
%   导致 depsamplesT 出错。
% -----------------------------------------------------------------------
function tl_out = average_conditions(timelock_row)
    K      = numel(timelock_row);
    tl_out = timelock_row{1};
    for k  = 2:K
        tl_out.avg = tl_out.avg + timelock_row{k}.avg;
    end
    tl_out.avg = tl_out.avg / K;
end

% -----------------------------------------------------------------------
% subtract_timelock：返回 A.avg - B.avg，其余字段继承自 A
% -----------------------------------------------------------------------
function tl_out = subtract_timelock(tlA, tlB)
    if ~isequal(size(tlA.avg), size(tlB.avg))
        error('subtract_timelock: .avg 尺寸不一致');
    end
    tl_out     = tlA;
    tl_out.avg = tlA.avg - tlB.avg;
end

% -----------------------------------------------------------------------
% run_paired_cluster_test
%   配对样本双侧聚类置换检验（depsamplesT）。
%   dataA / dataB：1×n_sub cell，每格是单被试 timelock 结构。
% -----------------------------------------------------------------------
function stat = run_paired_cluster_test(dataA, dataB, neighbours, ...
        num_perm, cluster_alpha, stat_alpha, latency)
    n_sub = length(dataA);
    cfg                  = [];
    cfg.method           = 'montecarlo';
    cfg.statistic        = 'depsamplesT';
    cfg.correctm         = 'cluster';
    cfg.clusteralpha     = cluster_alpha;
    cfg.clusterstatistic = 'maxsum';   % Maris & Oostenveld 2007 推荐
    cfg.minnbchan        = 2;
    cfg.tail             = 0;
    cfg.clustertail      = 0;
    cfg.alpha            = stat_alpha;
    cfg.numrandomization = num_perm;
    cfg.latency          = latency;
    cfg.neighbours       = neighbours;
    % 设计矩阵：行1=被试编号，行2=条件（1/2）
    cfg.design  = [1:n_sub, 1:n_sub; ones(1,n_sub), 2*ones(1,n_sub)];
    cfg.ivar    = 2;
    cfg.uvar    = 1;
    stat = ft_timelockstatistics(cfg, dataA{:}, dataB{:});
end

% -----------------------------------------------------------------------
% run_onesample_cluster_test
%   单样本聚类置换检验：差值 vs 0（用配对检验实现）。
% -----------------------------------------------------------------------
function stat = run_onesample_cluster_test(diff_waves, neighbours, ...
        num_perm, cluster_alpha, stat_alpha, latency)
    n_sub      = length(diff_waves);
    zero_waves = cell(1, n_sub);
    for i = 1:n_sub
        z        = diff_waves{i};
        z.avg    = zeros(size(z.avg));
        zero_waves{i} = z;
    end
    stat = run_paired_cluster_test(diff_waves, zero_waves, neighbours, ...
        num_perm, cluster_alpha, stat_alpha, latency);
end

% -----------------------------------------------------------------------
% bin_timelock：时间分箱平均
% -----------------------------------------------------------------------
function tl_out = bin_timelock(tl, bin_size_ms)
    time_ms   = tl.time * 1000;
    bin_edges = time_ms(1) : bin_size_ms : time_ms(end);
    if bin_edges(end) < time_ms(end)
        bin_edges(end+1) = time_ms(end);
    end
    n_bins  = length(bin_edges) - 1;
    new_avg = zeros(size(tl.avg, 1), n_bins);
    for b = 1:n_bins
        in_bin = time_ms >= bin_edges(b) & time_ms < bin_edges(b+1);
        if ~any(in_bin)   % 处理最后一个 bin 右边界
            in_bin = time_ms >= bin_edges(b) & time_ms <= bin_edges(b+1);
        end
        new_avg(:, b) = mean(tl.avg(:, in_bin), 2);
    end
    tl_out        = tl;
    tl_out.avg    = new_avg;
    tl_out.time   = (bin_edges(1:n_bins) + bin_size_ms/2) / 1000;
    tl_out.dimord = 'chan_time';
    % 移除分箱后不再适用的字段
    for fld = {'trial','cov','var'}
        if isfield(tl_out, fld{1}); tl_out = rmfield(tl_out, fld{1}); end
    end
end

% -----------------------------------------------------------------------
% export_clusters_to_excel：显著聚类信息写入 Excel
% -----------------------------------------------------------------------
function export_clusters_to_excel(stat, filename)
    rows    = {};
    row     = 1;
    time_ms = stat.time * 1000;

    for polarity = {'pos','neg'}
        pol      = polarity{1};
        clusters = stat.([pol 'clusters']);
        labelmat_field = [pol 'clusterslabelmat'];
        if isempty(clusters) || ~isfield(stat, labelmat_field); continue; end
        labelmat = stat.(labelmat_field);
        type_str = [upper(pol(1)) pol(2:end) 'itive'];  % 'Positive'/'Negative'

        for k = 1:length(clusters)
            if clusters(k).prob >= 0.05; continue; end
            mask     = (labelmat == k);
            time_idx = any(mask, 1);
            if ~any(time_idx); continue; end
            t_start  = time_ms(find(time_idx, 1, 'first'));
            t_end    = time_ms(find(time_idx, 1, 'last'));
            chan_idx = any(mask, 2);
            ch_list  = strjoin(stat.label(chan_idx), ', ');
            rows(row,:) = {k, type_str, clusters(k).prob, t_start, t_end, sum(chan_idx), ch_list};
            row = row + 1;
        end
    end

    if ~isempty(rows)
        T = cell2table(rows, 'VariableNames', ...
            {'Cluster','Type','p_value','TimeStart_ms','TimeEnd_ms','N_electrodes','Electrodes'});
        writetable(T, filename);
        fprintf('  已保存: %s\n', filename);
    else
        fprintf('  无显著聚类，跳过: %s\n', filename);
    end
end

% -----------------------------------------------------------------------
% plot_clusters：时空显著性热图（红=正聚类，蓝=负聚类，白=无显著）
% -----------------------------------------------------------------------
function plot_clusters(stat, chan_order, time_range_ms, output_fig, title_str)
    time_ms   = stat.time * 1000;
    t_mask    = time_ms >= time_range_ms(1) & time_ms <= time_range_ms(2);
    time_plot = time_ms(t_mask);
    n_chan    = length(chan_order);
    n_time    = sum(t_mask);

    [~, idx_in_stat] = ismember(chan_order, stat.label);
    valid     = idx_in_stat > 0;
    valid_idx = find(valid);
    stat_idx  = idx_in_stat(valid);

    pos_img = zeros(n_chan, n_time);
    neg_img = zeros(n_chan, n_time);

    for polarity = {'pos','neg'}
        pol      = polarity{1};
        clusters = stat.([pol 'clusters']);
        lmat_fld = [pol 'clusterslabelmat'];
        if isempty(clusters) || ~isfield(stat, lmat_fld); continue; end
        labelmat = stat.(lmat_fld);
        if strcmp(pol,'pos'); img = pos_img; else; img = neg_img; end
        for k = 1:length(clusters)
            if clusters(k).prob >= 0.05; continue; end
            full_mask = (labelmat == k);
            sub_mask  = full_mask(stat_idx, t_mask);
            img(valid_idx, :) = img(valid_idx, :) + double(sub_mask) * k;
        end
        if strcmp(pol,'pos'); pos_img = img; else; neg_img = img; end
    end

    % RGB 图：白底，正→红，负→蓝
    rgb = ones(n_chan, n_time, 3);
    if any(pos_img(:) > 0)
        for k = 1:max(pos_img(:))
            m     = (pos_img == k);
            intens = max(0.35, 1 - 0.5/k);
            rgb(:,:,1) = rgb(:,:,1).*~m + intens*m;
            rgb(:,:,2) = rgb(:,:,2).*~m + 0.10  *m;
            rgb(:,:,3) = rgb(:,:,3).*~m + 0.10  *m;
        end
    end
    if any(neg_img(:) > 0)
        for k = 1:max(neg_img(:))
            m     = (neg_img == k);
            intens = max(0.35, 1 - 0.5/k);
            rgb(:,:,1) = rgb(:,:,1).*~m + 0.10  *m;
            rgb(:,:,2) = rgb(:,:,2).*~m + 0.10  *m;
            rgb(:,:,3) = rgb(:,:,3).*~m + intens*m;
        end
    end

    figure('Color','w','Position',[100 100 1400 900]);
    image(time_plot, 1:n_chan, rgb);
    set(gca,'YDir','normal');
    yticks(1:n_chan);  yticklabels(chan_order);
    xlabel('Time (ms)');  ylabel('Electrode');
    title(title_str, 'FontSize', 13);
    xlim(time_range_ms);  ylim([0.5, n_chan+0.5]);
    grid on; box on; set(gca,'FontSize', 8);

    % 标注 p 值
    hold on;
    for polarity = {'pos','neg'}
        pol      = polarity{1};
        clusters = stat.([pol 'clusters']);
        lmat_fld = [pol 'clusterslabelmat'];
        if isempty(clusters) || ~isfield(stat, lmat_fld); continue; end
        labelmat = stat.(lmat_fld);
        col = 'r'; if strcmp(pol,'neg'); col = 'b'; end
        for k = 1:length(clusters)
            if clusters(k).prob >= 0.05; continue; end
            combined             = zeros(n_chan, n_time);
            combined(valid_idx,:) = (labelmat(stat_idx, t_mask) == k);
            t_any = any(combined, 1);
            c_any = any(combined, 2);
            if ~any(t_any); continue; end
            text(time_plot(find(t_any,1,'last')), find(c_any,1,'last')+0.5, ...
                 sprintf('p=%.3f', clusters(k).prob), ...
                 'Color',col,'FontSize',9,'FontWeight','bold', ...
                 'HorizontalAlignment','right');
        end
    end
    hold off;

    saveas(gcf, output_fig);
    savefig(gcf, strrep(output_fig, '.png', '.fig'));
    close(gcf);
    fprintf('  已保存图: %s\n', output_fig);
end