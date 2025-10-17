function progressbar(step, total)
    % Persistent vars to keep state across calls
    persistent lastStr startTime lastTotal
    
    % Initialize or reset on first call or new total
    if isempty(lastStr) || total ~= lastTotal || step == 1
        lastStr = '';
        lastTotal = total;
        startTime = tic;
    end
    
    % Compute progress
    percentComplete = (step / total) * 100;
    barWidth = 20;  % length of the progress bar
    numBars = round(percentComplete / (100 / barWidth));
    progressBar = ['[', repmat('#', 1, numBars), repmat('-', 1, barWidth - numBars), ']'];
    
    % Compute elapsed and ETA
    elapsed = toc(startTime);
    if step > 0
        estTotal = elapsed / (step / total);
        eta = max(estTotal - elapsed, 0);
    else
        eta = NaN;
    end
    
    % Format time as mm:ss
    fmtTime = @(t) sprintf('%02d:%02d', floor(t/60), mod(round(t), 60));
    elapsedStr = fmtTime(elapsed);
    etaStr = fmtTime(eta);
    
    % Build the string in tqdm style
    newStr = sprintf('%s %5.1f%% | elapsed: %s, ETA: %s', progressBar, percentComplete, elapsedStr, etaStr);
    
    % Overwrite previous output
    fprintf(repmat('\b', 1, length(lastStr)));
    fprintf('%s', newStr);
    lastStr = newStr;
    
    % End cleanly at completion
    if step == total
        fprintf('\n');
        lastStr = '';
    end
end
