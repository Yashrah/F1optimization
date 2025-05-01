
%  F1 Race Strategy Optimization for multiple tracks

clear; clc; close all; % Start with a clean workspace

fprintf('F1 Race Strategy Optimization - MATLAB\n');
fprintf('=======================================\n');
fprintf('Start Time: %s\n\n', datestr(now));

% Configuration
% SELECT TRACKS TO RUN
tracks_to_analyze = { ...
    struct('Name', 'Australian Grand Prix', 'Folder', 'Aus', 'Year', 2025, 'Session', 'Practice 2'), ...
    struct('Name', 'Monaco Grand Prix',     'Folder', 'Monaco','Year', 2024, 'Session', 'Race'), ...
    struct('Name', 'Japanese Grand Prix',   'Folder', 'Japan', 'Year', 2025, 'Session', 'Practice 3'), ...
    struct('Name', 'Bahrain Grand Prix',    'Folder', 'Bahrain','Year', 2025, 'Session', 'Race') ...
};

USE_UNCERTAINTY = true; % true: Optimize (K,M) using GA | false: Optimize fixed strategy (Grid Search)
BASE_DATA_FOLDER = 'data'; % Base folder containing track subfolders

%Data Fitting Configuration 
TARGET_DRIVER = 'VER';
TARGET_COMPOUND = 'MEDIUM';
TARGET_STINT = 1;

%Visualization Configuration 
RUN_DETAILED_SIM_FOR_TRACK = 'Australian Grand Prix'; % Choose one track for lap-by-lap plots
LOCAL_HEATMAP_RANGE = 5; % +/- laps around optimum for local heatmap

% Storage for Comparative Results
num_tracks = length(tracks_to_analyze);
comparison_results = struct('TrackName', cell(1, num_tracks), ...
                            'OptimalK', NaN(1, num_tracks), ...
                            'OptimalM', NaN(1, num_tracks), ...
                            'MinExpectedTime', NaN(1, num_tracks), ...
                            'ComputationTime', NaN(1, num_tracks));

% Loop Through Each Track
for i_track = 1:num_tracks
    current_track = tracks_to_analyze{i_track};
    fprintf('\n\n===== Processing Track: %s (%d) =====\n', current_track.Name, current_track.Year);

    % Construct file path for data fitting
    track_data_folder = fullfile(BASE_DATA_FOLDER, current_track.Folder);
    csv_filename = sprintf('%d-%s-%s.csv', current_track.Year, current_track.Name, current_track.Session);
    csv_filepath = fullfile(track_data_folder, csv_filename);

    %Load Parameters and Models
    fprintf('--- Loading Parameters and Models for %s ---\n', current_track.Name);
    race_params = define_race_parameters(current_track.Year, current_track.Name);
    try
        tire_models = define_data_driven_tire_models(csv_filepath, TARGET_DRIVER, TARGET_COMPOUND, TARGET_STINT);
    catch ME
        warning('Track %s: Could not load data-driven tire models. Using placeholder models. Error: %s', current_track.Name, ME.message);
        tire_models = define_placeholder_tire_models();
    end

    % Validate Inputs
    if isempty(tire_models) || isempty(race_params), error('Track %s: Failed to load parameters or tire models.', current_track.Name); end
    if race_params.num_laps <= 0, error('Track %s: Number of laps must be positive.', current_track.Name); end
    fprintf('-----------------------------------------------\n\n');

    % Run Optimization 
    fprintf('--- Starting Optimization for %s (Using Genetic Algorithm) ---\n', current_track.Name);
    tic;
    optimal_strategy = []; min_objective_value = Inf; % Initialize
    try
        [optimal_strategy, min_objective_value, ~, ~, ~] = ...
            find_optimal_strategy(race_params, tire_models, USE_UNCERTAINTY);
    catch ME
        fprintf('\nError during optimization for %s: %s\n', current_track.Name, ME.message);
        disp(ME.getReport());
    end
    elapsed_time = toc;
    fprintf('--- Optimization Finished for %s ---\n', current_track.Name);

    % Store Results
    comparison_results(i_track).TrackName = current_track.Name;
    comparison_results(i_track).ComputationTime = elapsed_time;
    if ~isempty(optimal_strategy) && isfinite(min_objective_value)
        comparison_results(i_track).OptimalK = optimal_strategy(1);
        comparison_results(i_track).OptimalM = optimal_strategy(2);
        comparison_results(i_track).MinExpectedTime = min_objective_value;
        fprintf('\n--- Optimal Strategy Found for %s ---\n', current_track.Name);
        fprintf(' Optimal K=%d, Optimal M=%d, Min Expected Time=%.2fs (%.2f min)\n', optimal_strategy(1), optimal_strategy(2), min_objective_value, min_objective_value/60);
        fprintf(' Optimization Time: %.2f seconds\n', elapsed_time);

        K_opt = optimal_strategy(1); M_opt = optimal_strategy(2);

        % Distribution Plot (using evaluate_strategy)
        fprintf('\n Generating Result Distribution Plot for %s...\n', current_track.Name);
        try
            [~, simulation_times_hist] = evaluate_strategy([K_opt, M_opt], race_params, tire_models, true, 'dynamic_KM'); % Assumes evaluate_strategy returns times
            figure('Name', sprintf('Result Distribution - %s', current_track.Name));
            histogram(simulation_times_hist, 50); hold on;
            xline(min_objective_value, 'r--', 'LineWidth', 2, 'Label', sprintf('Mean = %.2fs', min_objective_value));
            xlabel('Simulated Total Race Time (seconds)'); ylabel('Frequency');
            title({sprintf('Distribution: Optimal Strategy (K=%d, M=%d) - %s', K_opt, M_opt, current_track.Name), ...
                   sprintf('%d Simulations, SC Prob=%.2f', length(simulation_times_hist), race_params.safety_car_probability_per_lap)});
            grid on; hold off;
            fprintf(' Visual: Displayed Result Distribution Histogram.\n');
        catch ME_hist
            warning('Could not generate distribution plot for %s: %s', current_track.Name, ME_hist.message);
        end

        % Local Heatmap around Optimum
        fprintf('\n Generating Local Heatmap for %s...\n', current_track.Name);
        try
            k_range = max(1, K_opt - LOCAL_HEATMAP_RANGE) : min(race_params.num_laps - 1, K_opt + LOCAL_HEATMAP_RANGE);
            m_range = max(min(k_range)+1, M_opt - LOCAL_HEATMAP_RANGE) : min(race_params.num_laps, M_opt + LOCAL_HEATMAP_RANGE);
            local_results = NaN(length(k_range), length(m_range));
            fprintf(' Evaluating %d points for local heatmap...\n', length(k_range)*length(m_range));
            for i_k_local = 1:length(k_range)
                k_local = k_range(i_k_local);
                for i_m_local = 1:length(m_range)
                    m_local = m_range(i_m_local);
                    if k_local < m_local % Only evaluate valid strategies
                        local_results(i_k_local, i_m_local) = evaluate_strategy([k_local, m_local], race_params, tire_models, true, 'dynamic_KM');
                    end
                end
            end
            figure('Name', sprintf('Local Objective Landscape - %s', current_track.Name));
            imagesc(m_range, k_range, local_results); colorbar; axis xy; grid on;
            hold on; plot(M_opt, K_opt, 'r*', 'MarkerSize', 12, 'LineWidth', 2); hold off;
            xlabel('Mandatory Pit Lap (M)'); ylabel('SC Pit Threshold Lap (K)');
            title({sprintf('Local Landscape around Optimum (K=%d, M=%d) - %s', K_opt, M_opt, current_track.Name), ...
                   'Color represents Expected Race Time (s)'});
            set(gca, 'FontSize', 10);
             fprintf(' Visual: Displayed Local Heatmap.\n');
        catch ME_heatmap
             warning('Could not generate local heatmap for %s: %s', current_track.Name, ME_heatmap.message);
        end

        % Detailed Lap-by-Lap Simulation Plot (Only for specified track)
        if strcmpi(current_track.Name, RUN_DETAILED_SIM_FOR_TRACK)
             fprintf('\n Generating Detailed Lap Plot for %s...\n', current_track.Name);
             try
                 % Run one detailed simulation, logging data
                 [lap_data_table] = simulate_detailed_race([K_opt, M_opt], race_params, tire_models);

                 % Create Plots
                 figure('Name', sprintf('Detailed Simulation - %s (K=%d, M=%d)', current_track.Name, K_opt, M_opt));

                 % Lap Times Plot
                 subplot(3, 1, 1);
                 plot(lap_data_table.LapNumber, lap_data_table.LapTime, 'b.-'); hold on;
                 sc_laps = lap_data_table.LapNumber(lap_data_table.SC_Active);
                 plot(sc_laps, lap_data_table.LapTime(lap_data_table.SC_Active), 'rs', 'MarkerFaceColor', 'r', 'DisplayName', 'SC Active');
                 pit_lap = lap_data_table.LapNumber(lap_data_table.PitStop);
                 if ~isempty(pit_lap)
                    xline(pit_lap + 0.5, 'k--', 'LineWidth', 1.5, 'Label', sprintf('Pit Lap %d', pit_lap));
                 end
                 ylabel('Lap Time (s)'); title('Lap Times per Lap'); grid on; legend('show','Location','best');

                 % Tire Compound Plot
                 subplot(3, 1, 2);
                 compound_indices = lap_data_table.CompoundIndex;
                 tire_names_laps = {tire_models(compound_indices).name};
                 plot(lap_data_table.LapNumber, compound_indices, 'm.-');
                 yticks(1:length(tire_models));
                 yticklabels({tire_models.name});
                 ylabel('Tire Compound'); grid on; ylim([0.5, length(tire_models)+0.5]);
                 title('Tire Compound Usage');

                 % Cumulative Time Plot
                 subplot(3, 1, 3);
                 plot(lap_data_table.LapNumber, lap_data_table.CumulativeTime, 'g.-');
                 xlabel('Lap Number'); ylabel('Cumulative Time (s)');
                 title('Cumulative Race Time'); grid on;

                 sgtitle(sprintf('Detailed Simulation: %s (K=%d, M=%d)', current_track.Name, K_opt, M_opt));
                 fprintf(' Visual: Displayed Detailed Lap-by-Lap Plots.\n');

             catch ME_detail
                 warning('Could not generate detailed simulation plot for %s: %s', current_track.Name, ME_detail.message);
             end
        end % End detailed plot check

    else 
        fprintf('No valid strategy found or optimization failed for %s.\n', current_track.Name);
    end
    fprintf('==========================================\n');

end % End loop through tracks

% Final Visuals
fprintf('\n--- Generating Final Multi-Track Comparison Plot ---\n');
try
    figure('Name', 'Multi-Track Strategy Comparison');
    valid_results_idx = ~isnan([comparison_results.MinExpectedTime]); % Filter out tracks where optimization failed
    track_names = {comparison_results(valid_results_idx).TrackName};
    optimal_Ks = [comparison_results(valid_results_idx).OptimalK];
    optimal_Ms = [comparison_results(valid_results_idx).OptimalM];
    min_times = [comparison_results(valid_results_idx).MinExpectedTime];
    num_valid_tracks = length(track_names);

    if num_valid_tracks == 0
        error('No valid optimization results to plot.');
    end

    % Subplot 1: Optimal K and M
    subplot(2, 1, 1);
    bar_data_KM = [optimal_Ks', optimal_Ms']; % K first, then M
    b_KM = bar(bar_data_KM, 'stacked');
    set(gca, 'xticklabel', track_names, 'XTickLabelRotation', 15); % Rotate labels if needed
    ylabel('Optimal Lap Number');
    title('Optimal Strategy (K and M) Across Tracks');
    legend({'K (SC Threshold)', 'M (Mandatory Pit)'}, 'Location', 'NorthWest'); % Correct legend order if needed
    grid on;
    ylim([0, max(optimal_Ms)*1.1 + 5]);

    % Add text labels for K and M values
    for i = 1:num_valid_tracks
        k_val = optimal_Ks(i);
        m_val = optimal_Ms(i);
        if ~isnan(k_val)
             text(i, k_val/2, sprintf('K=%d', k_val), ...
                 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Color', 'w', 'FontSize', 8, 'FontWeight', 'bold');
        end
         if ~isnan(m_val) && ~isnan(k_val)
             text(i, k_val + (m_val-k_val)/2, sprintf('M=%d', m_val), ... % Position text in the M part
                 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Color', 'k', 'FontSize', 8, 'FontWeight', 'bold');
         elseif ~isnan(m_val) 
              text(i, m_val/2, sprintf('M=%d', m_val), ...
                 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Color', 'k', 'FontSize', 8, 'FontWeight', 'bold');
         end
    end
    b_KM(1).FaceColor = [0 0.4470 0.7410]; % Blue for K
    b_KM(2).FaceColor = [0.8500 0.3250 0.0980]; % Orange for M-K part

    % Subplot 2: Minimum Expected Time
    subplot(2, 1, 2);
    b_time = bar(min_times);
    set(gca, 'xticklabel', track_names, 'XTickLabelRotation', 15);
    ylabel('Min Expected Time (s)');
    title('Minimum Expected Race Time Comparison');
    grid on;
    if ~isempty(min_times)
        ylim([min(min_times)*0.99, max(min_times)*1.01]);
        xtips_time = b_time.XEndPoints;
        ytips_time = b_time.YEndPoints;
        labels_time = string(round(b_time.YData,1));
        text(xtips_time,ytips_time,labels_time,'HorizontalAlignment','center',...
            'VerticalAlignment','bottom', 'FontSize', 9);
    end

    sgtitle('F1 Strategy Optimization Results Comparison Across Tracks'); % Overall title

    fprintf(' Visual: Displayed Multi-Track Comparison Plot.\n');
     %

catch ME_compare_final
    warning('Could not generate final comparison plot: %s', ME_compare_final.message);
end

fprintf('\n--- End of Multi-Track Simulation ---\n');
