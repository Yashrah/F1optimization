
function tire_models = define_data_driven_tire_models(csv_filepath, target_driver, target_compound_name, target_stint)
    % Defines tire models by fitting data from a CSV file for one compound,
    % and uses placeholder models for others.

    fprintf('--- Defining Data-Driven Tire Models ---\n');
    tire_models = define_placeholder_tire_models(); % Start with placeholders

    try
        % Fit the target tire model
        fitted_params = fit_tire_model_from_csv(csv_filepath, target_driver, target_compound_name, target_stint);

        % Find the index corresponding to the target compound name
        compound_idx = -1;
        for i = 1:length(tire_models)
            % Use strcmpi for case-insensitive comparison, check if name contains target
            if contains(tire_models(i).name, target_compound_name, 'IgnoreCase', true)
                compound_idx = i;
                break;
            end
        end

        if compound_idx > 0
            fprintf('Updating model for %s (Index %d) with data-driven parameters.\n', tire_models(compound_idx).name, compound_idx);
            tire_models(compound_idx).base_lap_time = fitted_params.base_lap_time;
            tire_models(compound_idx).degradation_func = fitted_params.degradation_func;
            tire_models(compound_idx).data_driven = true; % Add a flag
        else
            warning('Could not find placeholder model matching target compound name "%s". Using only placeholders.', target_compound_name);
        end

    catch ME
        warning('Error fitting data-driven model for %s: %s. Using placeholder models.', target_compound_name, ME.message);
        % Keep using the placeholder models defined initially
    end

    disp('Tire Models Defined.');
    for i = 1:length(tire_models)
        is_data_driven = isfield(tire_models(i), 'data_driven') && tire_models(i).data_driven;
        fprintf('  Model %d: %s (Data-Driven: %s)\n', i, tire_models(i).name, mat2str(is_data_driven));
    end
     fprintf('----------------------------------------\n');
end
