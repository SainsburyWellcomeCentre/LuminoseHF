function d = dprime(hits, nGo, falseAlarms, nNoGo)
% lhf.dprime  Sensitivity d' of a go/no-go run: z(hit rate) - z(false-alarm rate).
%
%   d = lhf.dprime(hits, nGo, falseAlarms, nNoGo)
%
%   hits of nGo Go trials, false alarms of nNoGo No-Go trials. Both rates use the
%   log-linear correction, (count + 0.5) / (trials + 1), so all hits or no false alarms
%   still give a finite d' (Hautus 1995, Behav Res Methods Instrum Comput 27:46-51).
%   z is the inverse standard normal, from erfcinv (base MATLAB). 0 is chance.
%
% See also lhf.plot.dprime

    h = (hits + 0.5) ./ (nGo + 1);
    f = (falseAlarms + 0.5) ./ (nNoGo + 1);
    d = z(h) - z(f);
end


function v = z(p)
    v = -sqrt(2) * erfcinv(2 * p);
end
