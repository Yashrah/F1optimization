
function [expected_time, simulation_times] = evaluate_strategy(strategy_params, race_params, tire_models, use_uncertainty, strategy_type)
    % Evaluates a strategy based on type.
    % K = Pit if SC occurs >= lap K. M = Mandatory pit lap if no SC pit occurred.
    simulation_times = []; %
    % data type validation
    if ~isstruct(race_params) || ~isstruct(tire_models)
        error('race_params and tire_models must be structs.');
    end
    if ~islogical(use_uncertainty)
        error('use_uncertainty must be logical (true/false).');
    end

    if strcmp(strategy_type, 'fixed')
        if use_uncertainty
             warning('Evaluating fixed strategy deterministically, ignoring uncertainty flag.');
             % Or: you could adapt simulate_race to handle uncertainty for fixed plans too
        end
        % Call simulate_race_fixed
      
        expected_time = simulate_race_fixed(strategy_params, race_params, tire_models);

    elseif strcmp(strategy_type, 'dynamic_KM')
        if ~use_uncertainty
            error('Dynamic KM strategy requires uncertainty simulation.');
        end

        % Validate strategy_params format
        if ~isnumeric(strategy_params) || numel(strategy_params) ~= 2
            error('For dynamic_KM, strategy_params must be a 1x2 numeric vector [K, M].');
        end

        K = round(strategy_params(1)); % Ensure integer K
        M = round(strategy_params(2)); % Ensure integer M

        % Validate K and M values
        if K < 1 || M < 1 || M > race_params.num_laps
             warning('K or M value is out of reasonable bounds. K=%d, M=%d', K, M);
             expected_time = Inf; % Penalize invalid K or M
             return;
        end
        if K >= M
           
            expected_time = Inf; % Invalid strategy: SC threshold >= Mandatory pit lap
            return;
        end

        start_compound_idx = race_params.start_compound_idx; % Get start compound

        % Determine the compound index for the second stint based on rules
        available_compounds = 1:length(tire_models);
      
        % Ensure start_compound_idx is valid
        if start_compound_idx < 1 || start_compound_idx > length(tire_models)
            error('Invalid start_compound_idx: %d', start_compound_idx);
        end

        next_compound_idx = find(available_compounds ~= start_compound_idx, 1, 'first');
        if isempty(next_compound_idx) && length(tire_models) > 1 && race_params.must_use_different_compound
             warning('Could not find a different compound for mandatory change! Strategy may be invalid.');
             next_compound_idx = start_compound_idx; % Fallback, may violate rules
        elseif isempty(next_compound_idx)
             next_compound_idx = start_compound_idx; % Only one compound defined
        end

        %Monte Carlo Simulation for (K, M)
        num_sims = race_params.num_simulations_for_expected_time;
        simulation_times = zeros(num_sims, 1);


        for i = 1:num_sims
            % Initialize simulation variables for this run
            total_time_run = 0;
            current_lap_run = 0;
            laps_on_current_tire_run = 0;
            current_compound_idx_run = start_compound_idx;
            pitted_run = false;


            % --- Race Simulation Loop ---
            while current_lap_run < race_params.num_laps
                current_lap_run = current_lap_run + 1;
                laps_on_current_tire_run = laps_on_current_tire_run + 1;

                % Get tire model and calculate base lap time + degradation
                tire = tire_models(current_compound_idx_run);
                base_time = tire.base_lap_time;
                % Ensure degradation function handles potential non-vectorized inputs if needed
                try
                    degradation = tire.degradation_func(laps_on_current_tire_run);
                catch ME_deg
                    error('Error evaluating degradation function for tire %s at age %d: %s', tire.name, laps_on_current_tire_run, ME_deg.message);
                end
                lap_time = base_time + degradation;

                % Check for pit decision *for the end of this lap*
                pit_decision_this_lap = false;
                pit_cost_this_lap = 0; % Cost incurred *after* this lap

                if ~pitted_run
                    % Check for SC event *this lap*
                    sc_occurred_this_lap = (rand() < race_params.safety_car_probability_per_lap);

                    % Check for SC pit opportunity (SC occurs AND we are at or past lap K)
                    if sc_occurred_this_lap && current_lap_run >= K
                        pit_decision_this_lap = true;
                        pit_cost_this_lap = race_params.pit_stop_time_loss_sc; % Free/cheap pit
                    % Check for mandatory pit (lap M reached)
                    elseif current_lap_run == M
                         pit_decision_this_lap = true;
                         pit_cost_this_lap = race_params.pit_stop_time_loss; % Normal cost
                    end

                    % If pitting this lap, update state for *next* lap
                    if pit_decision_this_lap
                        pitted_run = true;
                        current_compound_idx_run = next_compound_idx;
                        laps_on_current_tire_run = 0; % Reset tire age for next lap
                        % Pit cost is added *after* the current lap time
                    end
                end

                % Add lap time and any pit cost from the *previous* lap's decision
                total_time_run = total_time_run + lap_time;
                
                if pit_decision_this_lap % Add cost if pit decision was made for end of this lap
                     total_time_run = total_time_run + pit_cost_this_lap;
                end


            end % End while loop 
            simulation_times(i) = total_time_run;
        end % End Monte Carlo loop

        expected_time = mean(simulation_times);

       

    else
        error('Unknown strategy_type: %s', strategy_type);
    end
end

%  simulate_race_fixed

function total_time = simulate_race_fixed(strategy, race_params, tire_models)
    % Simplified simulation for a fixed strategy matrix (deterministic)
    total_time = 0;
    current_lap = 0;
    num_stints = size(strategy, 1);

    for stint_idx = 1:num_stints
        compound_idx = strategy(stint_idx, 1);
        stint_laps = strategy(stint_idx, 2);
        tire = tire_models(compound_idx);

        for lap_in_stint = 1:stint_laps
            current_lap = current_lap + 1;
            if current_lap > race_params.num_laps
                break;
            end
            tire_age = lap_in_stint;
            lap_time = tire.base_lap_time + tire.degradation_func(tire_age);
            total_time = total_time + lap_time;
        end

        if stint_idx < num_stints && current_lap <= race_params.num_laps
            total_time = total_time + race_params.pit_stop_time_loss;
        end
        if current_lap > race_params.num_laps, break; end
    end

    if current_lap < race_params.num_laps
        warning('Fixed strategy did not complete the full race distance!');
        total_time = Inf;
    end
end

