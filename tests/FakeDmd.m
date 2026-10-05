classdef FakeDmd < handle
% FakeDmd  Stands in for a connected DMDController.DMD: records what it is asked to show.

    properties
        Calls = {}        % command names, in order
        LastFrame = []    % the last frame given to displayFrame
    end

    methods
        function displayFrame(obj, image, varargin)
            obj.Calls{end + 1} = 'displayFrame';
            obj.LastFrame = image;
        end

        function halt(obj)
            obj.Calls{end + 1} = 'halt';
        end

        function disconnect(obj)
            obj.Calls{end + 1} = 'disconnect';
        end
    end
end
