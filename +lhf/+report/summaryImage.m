function summaryImage(data, info, file)
% lhf.report.summaryImage  The live plots redrawn over the whole session, saved as an image.
%
%   lhf.report.summaryImage(data, info, file)
%
%   The same panels as the live window (lhf.plot.*), in an invisible figure,
%   with the outcome and accuracy axes showing every trial rather than the
%   last 100-200. Saved at 150 dpi.

    [fig, ax] = lhf.plot.createFigure('Visible', 'off');
    closer = onCleanup(@() delete(fig));

    n = numel(data.TrialOutcome);
    lhf.plot.outcome(ax.Outcome, 'init', info, []);
    upTo = data;
    for i = 1:n
        upTo.nTrials = i;
        lhf.plot.outcome(ax.Outcome, 'update', upTo, []);
    end
    ax.Outcome.XLim = [0 n + 1];
    title(ax.Outcome, sprintf('luminose\\_hf\\_%s: %d trials', info.name, n));

    lhf.plot.accuracy(ax.Accuracy, 'init', info);
    lhf.plot.accuracy(ax.Accuracy, 'update', data);
    ax.Accuracy.XLim = [1 max(2, n)];

    lhf.plot.reward(ax.Reward, 'init');
    lhf.plot.reward(ax.Reward, 'update', data);

    lhf.plot.responseTime(ax.Response, 'init');
    lhf.plot.responseTime(ax.Response, 'update', data);

    lhf.plot.encoder(ax.Encoder, 'init', 0);
    if isfield(data, 'EncoderData') && numel(data.EncoderData) >= n && isstruct(data.EncoderData{n})
        lhf.plot.encoder(ax.Encoder, 'update', 0, data.EncoderData{n}, NaN);
    end

    exportgraphics(fig, file, 'Resolution', 150);
end
