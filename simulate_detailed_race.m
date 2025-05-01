% --- File: simulate_detailed_race.m (New File) ---
function lap_data_table = simulate_detailed_race(strategy_params, race_params, tire_models)
    % Simulates one race using the (K,M) strategy, logging lap-by-lap details.
    % INPUTS:
    %   strategy_params: [K, M] vector
    %   race_params: Struct with race parameters
    %   tire_models: Struct array with tire models
    % OUTPUT:
    %   lap_data_table: Table containing detailed data for each lap

    K = round(strategy_params(1));
    M = round(strategy_params(2));
    start_compound_idx = race_params.start_compound_idx;
    num_laps = race_params.num_laps;

    % Determine next compound index
    available_compounds = 1:length(tire_models);
    next_compound_idx = find(available_compounds ~= start_compound_idx, 1, 'first');
    if isempty(next_compound_idx) && length(tire_models) > 1 && race_params.must_use_different_compound, next_compound_idx = start_compound_idx; end
    if isempty(next_compound_idx), next_compound_idx = start_compound_idx; end

    % Preallocate logging arrays
    lap_numbers = (1:num_laps)';
    lap_times = NaN(num_laps, 1);
    cumulative_times = NaN(num_laps, 1);
    compound_indices = NaN(num_laps, 1);
    tire_ages = NaN(num_laps, 1);
    sc_active_flags = false(num_laps, 1);
    pit_stop_flags = false(num_laps, 1);

    % Simulation variables
    total_time_run = 0;
    current_lap_run = 0;
    laps_on_current_tire_run = 0;
    current_compound_idx_run = start_compound_idx;
    pitted_run = false;
    laps_remaining_sc_internal = 0; % Internal counter for SC duration

    fprintf(' Starting detailed simulation (K=%d, M=%d)...\n', K, M);

    % --- Race Simulation Loop ---
    while current_lap_run < num_laps
        current_lap_run = current_lap_run + 1;
        laps_on_current_tire_run = laps_on_current_tire_run + 1;

        % Get tire model and calculate base lap time + degradation
        tire = tire_models(current_compound_idx_run);
        base_time = tire.base_lap_time;
        degradation = tire.degradation_func(laps_on_current_tire_run);
        lap_time = base_time + degradation;
        sc_active_this_lap = false; % Flag for logging

        % Check for pit decision *for the end of this lap*
        pit_decision_this_lap = false;
        pit_cost_this_lap = 0; % Cost incurred *after* this lap

        if ~pitted_run
             % Check for SC event *this lap* (only if not already under SC)
             sc_occurred_this_lap = false;
             if laps_remaining_sc_internal == 0 % Check only if not already in SC
                 sc_occurred_this_lap = (rand() < race_params.safety_car_probability_per_lap);
                 if sc_occurred_this_lap
                     laps_remaining_sc_internal = race_params.safety_car_duration_laps;
                     fprintf('  Detailed Sim: SC deployed on lap %d\n', current_lap_run);
                 end
             end

             % --- Apply SC Effects if active ---
             if laps_remaining_sc_internal > 0
                 sc_active_this_lap = true;
                 ref_idx = min(3, length(tire_models)); % Use Hard tire as reference
                 ref_sc_base_time = tire_models(ref_idx).base_lap_time;
                 lap_time = ref_sc_base_time + race_params.safety_car_lap_time_delta; % Override calculated lap time
                 laps_remaining_sc_internal = laps_remaining_sc_internal - 1; % Decrement counter
             end

  
            % Check for SC pit opportunity (SC occurred AND we are at or past lap K)
            if sc_occurred_this_lap && current_lap_run >= K % Pit if SC deployed *this lap* and >= K
                pit_decision_this_lap = true;
                pit_cost_this_lap = race_params.pit_stop_time_loss_sc;
                fprintf('  Detailed Sim: SC Pit triggered on lap %d (K=%d)\n', current_lap_run, K);
            % Check for mandatory pit (lap M reached)
            elseif current_lap_run == M
                 pit_decision_this_lap = true;
                 pit_cost_this_lap = race_params.pit_stop_time_loss;
                 fprintf('  Detailed Sim: Mandatory Pit triggered on lap %d (M=%d)\n', current_lap_run, M);
            end

            % If pitting this lap, update state for *next* lap
            if pit_decision_this_lap
                pitted_run = true;
                current_compound_idx_run = next_compound_idx;
                laps_on_current_tire_run = 0; % Reset tire age for next lap
                pit_stop_flags(current_lap_run) = true; % Log the pit stop
                % Note: Pit cost is added *after* the current lap time
            end
        end % end if ~pitted_run

        % Accumulate time and Log data for the *completed* lap
        total_time_run = total_time_run + lap_time;
        if pit_decision_this_lap % Add pit cost if decision was made for end of this lap
             total_time_run = total_time_run + pit_cost_this_lap;
        end

        lap_times(current_lap_run) = lap_time;
        cumulative_times(current_lap_run) = total_time_run;
        compound_indices(current_lap_run) = current_compound_idx_run; % Log compound used *during* this lap
        tire_ages(current_lap_run) = laps_on_current_tire_run; % Log age *at end* of this lap
        sc_active_flags(current_lap_run) = sc_active_this_lap;

    end % End while loop (race laps)

    % Create output table
    lap_data_table = table(lap_numbers, lap_times, cumulative_times, compound_indices, tire_ages, sc_active_flags, pit_stop_flags, ...
        'VariableNames', {'LapNumber', 'LapTime', 'CumulativeTime', 'CompoundIndex', 'TireAge', 'SC_Active', 'PitStop'});

    fprintf(' Detailed simulation finished.\n');
end
