function step(hooks, fraction, text)
% step  Reports progress and stops (lhf:cal:stopped) if Stop was pressed.
    hooks.progress(fraction, text);
    if hooks.shouldStop()
        error('lhf:cal:stopped', 'Stopped at: %s', text);
    end
end
