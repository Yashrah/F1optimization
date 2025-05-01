
function tire_model_params = fit_tire_model_from_csv(csv_filepath, target_driver, target_compound, target_stint)
    % Loads F1 lap data from a specific CSV, filters it for a driver/compound/stint,
    % and fits a quadratic degradation model.
    % Returns a struct with 'base_lap_time' and 'degradation_func' handle.

    fprintf('Attempting to fit tire model from: %s\n', csv_filepath);
    fprintf('Target - Driver: %s, Compound: %s, Stint: %d\n', target_driver, target_compound, target_stint);

    %Load Data
    if ~isfile(csv_filepath)
        error('CSV file not found: %s', csv_filepath);
    end

    opts = detectImportOptions(csv_filepath);
    % Ensure necessary columns are read correctly
    required_vars = {'LapTime', 'TyreLife', 'Stint', 'Driver', 'Compound', 'PitInTime', 'PitOutTime', 'TrackStatus', 'IsAccurate'};
    available_vars = opts.VariableNames;
    missing_vars = setdiff(required_vars, available_vars, 'stable');
    if ~isempty(missing_vars)
        error('CSV file %s is missing required columns: %s', csv_filepath, strjoin(missing_vars, ', '));
    end

    % Set variable types (adjust if needed based on actual CSV format)
    opts = setvartype(opts, {'LapTime', 'PitInTime', 'PitOutTime'}, 'duration');
    opts = setvartype(opts, {'TyreLife', 'Stint', 'TrackStatus'}, 'double'); % Assuming TrackStatus is numeric code
    opts = setvartype(opts, {'IsAccurate'}, 'logical');

    try
        data = readtable(csv_filepath, opts);
        fprintf('Loaded %d rows from %s.\n', height(data), csv_filepath);
    catch ME_read
        error('Failed to read CSV file %s. Error: %s', csv_filepath, ME_read.message);
    end

    %  Filter Data
    fprintf('Filtering data...\n');
    % Select driver (case-insensitive)
    driver_data = data(strcmpi(data.Driver, target_driver), :);
    if isempty(driver_data), error('Driver %s not found.', target_driver); end

    % Select compound (case-insensitive)
    compound_data = driver_data(strcmpi(driver_data.Compound, target_compound), :);
    if isempty(compound_data), error('Compound %s not found for driver %s.', target_compound, target_driver); end

    % Select stint
    stint_data = compound_data(compound_data.Stint == target_stint, :);
    if isempty(stint_data), error('Stint %d not found for driver %s on %s.', target_stint, target_driver, target_compound); end
    fprintf(' Found %d laps for Stint %d.\n', height(stint_data), target_stint);

    % Keep only accurate laps marked by FastF1
    stint_data = stint_data(stint_data.IsAccurate == true, :);
    fprintf('  %d laps marked as accurate.\n', height(stint_data));

    % Convert LapTime duration to seconds
    lap_times_sec = seconds(stint_data.LapTime);
    tire_ages = stint_data.TyreLife;

    % Filter out NaNs in lap time or tire age (should be minimal if IsAccurate=true)
    valid_idx = ~isnan(lap_times_sec) & ~isnan(tire_ages);
    lap_times_sec = lap_times_sec(valid_idx);
    tire_ages = tire_ages(valid_idx);
    stint_data = stint_data(valid_idx,:); % Filter original table too for Pit time checks
    fprintf('  %d laps with valid time and age.\n', length(lap_times_sec));

    % Filter out laps with PitInTime or PitOutTime (more robust than just first/last lap)
    % isnat checks if a datetime/duration is Not-a-Number
    is_pit_lap = ~isnan(seconds(stint_data.PitInTime)) | ~isnan(seconds(stint_data.PitOutTime));
    valid_idx = ~is_pit_lap;
    lap_times_sec = lap_times_sec(valid_idx);
    tire_ages = tire_ages(valid_idx);
    fprintf('  %d laps remaining after removing pit laps.\n', length(lap_times_sec));

    % --- TODO: Filter SC/VSC laps based on TrackStatus ---
    % TrackStatus codes (example, check FastF1 documentation): 1=Green, 2=Yellow, 4=SC, 5=Red, 6=VSC Deployed, 7=VSC Ending
    %valid_idx = stint_data.TrackStatus == 1; % Keep only green flag laps
    %lap_times_sec = lap_times_sec(valid_idx);
    %tire_ages = tire_ages(valid_idx);
    %fprintf('  %d laps remaining after removing non-green flag laps.\n', length(lap_times_sec));

    % Filter major outliers (e.g., >107% of median) - do this *after* other filtering
    if length(lap_times_sec) >= 3
        median_lap_time = median(lap_times_sec);
        threshold_upper = 1.07 * median_lap_time;
        threshold_lower = 0.93 * median_lap_time; % Also filter unusually fast laps
        valid_idx = (lap_times_sec < threshold_upper) & (lap_times_sec > threshold_lower);
        lap_times_sec_filtered = lap_times_sec(valid_idx);
        tire_ages_filtered = tire_ages(valid_idx);
        fprintf('  %d laps remaining after removing time outliers (%.2f%% - %.2f%% of median).\n', ...
                length(lap_times_sec_filtered), threshold_lower/median_lap_time*100, threshold_upper/median_lap_time*100);
    else
        lap_times_sec_filtered = lap_times_sec;
        tire_ages_filtered = tire_ages;
    end


    if length(lap_times_sec_filtered) < 3 % Need enough points to fit reliably
       error('Not enough valid laps (%d) found for fitting after all filters.', length(lap_times_sec_filtered));
    end

    %  Fit Curve ---
    fprintf('Fitting quadratic model to %d data points...\n', length(lap_times_sec_filtered));
    % Fit a quadratic model: LapTime = p1*age^2 + p2*age + p3
    degree = 2;
    % Use robust fitting option if available and needed (e.g., 'LAR' or 'Bisquare')
    try
        % Requires Curve Fitting Toolbox
        fit_options = fitoptions('poly2', 'Robust', 'LAR'); % Least Absolute Residuals
        fittype_poly2 = fittype('poly2');
        [fit_result, gof] = fit(tire_ages_filtered, lap_times_sec_filtered, fittype_poly2, fit_options);
        coeffs = coeffvalues(fit_result);
        p1 = coeffs(1); p2 = coeffs(2); p3 = coeffs(3);
        fprintf(' Robust fit R^2: %.4f\n', gof.rsquare);
    catch ME_fit
        warning('Curve Fitting Toolbox `fit` failed or not available: %s. Using basic polyfit.', ME_fit.message);
        coeffs = polyfit(tire_ages_filtered, lap_times_sec_filtered, degree);
        p1 = coeffs(1); p2 = coeffs(2); p3 = coeffs(3);
    end


    % Extract Parameters and Create Model ---
    % Estimate base lap time. Polyfit constant term p3 is estimate at age=0.
    % A slightly better estimate might be evaluating the fit at age=1.
    base_lap_time_est = polyval(coeffs, 1); % Estimate time for the first lap on the tire

    % Degradation function is the part dependent on age
    degradation_func = @(age) polyval(coeffs, age) - base_lap_time_est;
    % Alternative: degradation relative to p3 (time at age=0)
    % degradation_func = @(age) p1*age.^2 + p2*age;

    tire_model_params.base_lap_time = base_lap_time_est;
    tire_model_params.degradation_func = degradation_func;

    fprintf(' Fit Complete. Estimated Base Time (Lap 1): %.3fs\n', base_lap_time_est);
    fprintf('  Degradation function created from coeffs: p1=%.4f, p2=%.4f, p3=%.4f\n', p1, p2, p3);

    % Generate Visual Deliverable: Plot Fit
    try
        figure('Name', sprintf('Tire Fit: %s %s Stint %d', target_driver, target_compound, target_stint));
        plot(tire_ages, lap_times_sec, 'bo', 'DisplayName', 'Raw Stint Data (Filtered)'); % Plot original filtered points
        hold on;
        plot(tire_ages_filtered, lap_times_sec_filtered, 'rx', 'MarkerSize', 8, 'DisplayName', 'Data Used for Fit'); % Mark points used
        age_fit_plot = linspace(min(tire_ages_filtered), max(tire_ages_filtered), 100);
        lap_time_fit_plot = polyval(coeffs, age_fit_plot);
        plot(age_fit_plot, lap_time_fit_plot, 'k-', 'LineWidth', 2, 'DisplayName', ['Quadratic Fit (Deg=', num2str(degree), ')']);
        xlabel('Tire Age (Laps)');
        ylabel('Lap Time (seconds)');
        title({sprintf('Tire Degradation Fit: %s - %s - Stint %d', target_driver, target_compound, target_stint), ...
               sprintf('Base=%.3fs, Degradation=%.4f*age^2 + %.4f*age', base_lap_time_est, p1, p2)});
        legend('Location', 'NorthWest');
        grid on;
        hold off;
        % Optional: Save the figure
        % saveas(gcf, sprintf('tire_fit_%s_%s_stint%d.png', target_driver, target_compound, target_stint));
    catch ME_plot
        warning('Could not generate tire fit plot: %s', ME_plot.message);
    end

end