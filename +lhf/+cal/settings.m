function s = settings(cal, values)
% lhf.cal.settings  A calibration's settings as a struct, with some changed.
%
%   s = lhf.cal.settings(cal)            the defaults (cal from lhf.cal.catalog)
%   s = lhf.cal.settings(cal, values)    values (a struct) override them; a key the
%                                        calibration does not have is an error
%
%   Each value is checked against its kind: a number is one finite number, a vector
%   numbers, a logical true or false, a choice one of its choices.
%
% See also lhf.cal.catalog, lhf.cal.run

    if nargin < 2, values = struct(); end
    s = struct();
    for k = 1:numel(cal.settings)
        s.(cal.settings(k).key) = cal.settings(k).value;
    end
    for name = fieldnames(values)'
        key = name{1};
        k = find(strcmp({cal.settings.key}, key), 1);
        if isempty(k)
            error('lhf:cal:badSetting', '%s has no setting %s.', cal.title, key);
        end
        s.(key) = check(cal.settings(k), values.(key));
    end
end


function v = check(spec, v)
    bad = @(what) error('lhf:cal:badSetting', '%s must be %s.', spec.label, what);
    switch spec.kind
        case 'number'
            if ~(isnumeric(v) && isscalar(v) && isfinite(v)), bad('one number'); end
            v = double(v);
        case 'vector'
            if ~(isnumeric(v) && all(isfinite(v(:))) && ~isempty(v)), bad('a list of numbers'); end
            v = double(v(:)');
        case 'logical'
            if ~(islogical(v) || isnumeric(v)) || ~isscalar(v), bad('yes or no'); end
            v = logical(v);
        case 'choice'
            v = char(v);
            if ~any(strcmp(spec.choices, v)), bad(['one of ' strjoin(spec.choices, ', ')]); end
    end
end
