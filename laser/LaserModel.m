classdef LaserModel < handle
    % LaserModel  Serial control for Coherent OBIS laser via SCPI commands.
    %
    %   laser = LaserModel(luminose.laser)
    %   laser = LaserModel(luminose.laser, mode)
    %
    %   Connects to the OBIS remote on the configured COM port and sets the
    %   control mode. Call disconnect() when done.
    %
    %   mode  'cwp'     (default) internal CW power mode: emission follows
    %                   setEnabled() alone.
    %         'digital' external digital modulation: emission is gated by
    %                   the TTL on the OBIS modulation input (DMD pin 8),
    %                   at the power set by setPower(). Emission is
    %                   enabled on connect.

    properties
        port        string
        baudRate    double
        maxPower_mW double
        sp                  % serialport handle
    end

    methods
        function self = LaserModel(constants, mode)
            if nargin < 2 || isempty(mode)
                mode = 'cwp';
            end
            self.port        = constants.port;
            self.baudRate    = constants.baudRate;
            self.maxPower_mW = constants.maxPower_mW;

            self.sp = serialport(char(self.port), self.baudRate);
            configureTerminator(self.sp, "CR/LF");
            self.sp.Timeout = 5;

            switch lower(char(mode))
                case 'cwp'
                    % Switch to USB (CWP) control mode
                    writeline(self.sp, "SOURce:AM:INTernal CWP");
                    pause(0.1);
                case 'digital'
                    % External digital modulation: TTL gates emission
                    writeline(self.sp, "SOURce:AM:EXTernal DIGital");
                    pause(0.1);
                    self.setEnabled(true);
                    pause(0.1);
                otherwise
                    error('LaserModel:BadMode', ...
                        'Unknown mode ''%s'' (expected ''cwp'' or ''digital'').', char(mode));
            end
        end

        function setPower(self, mW)
            % setPower  Set laser output power.
            %   laser.setPower(mW)  — value in milliwatts
            if mW < 0 || mW > self.maxPower_mW
                error('LaserModel:OutOfRange', ...
                    'Power %.3f mW is outside [0, %.3f] mW range.', mW, self.maxPower_mW);
            end
            watts = mW / 1000;
            writeline(self.sp, sprintf('SOURce:POWer:LEVel:IMMediate:AMPLitude %.6f', watts));
        end

        function setEnabled(self, tf)
            % setEnabled  Enable or disable laser emission.
            %   laser.setEnabled(true)   — emission on
            %   laser.setEnabled(false)  — emission off
            if tf
                writeline(self.sp, "SOURce:AM:STATe ON");
            else
                writeline(self.sp, "SOURce:AM:STATe OFF");
            end
        end

        function mW = getPower_mW(self)
            % getPower_mW  Query actual output power in milliwatts.
            writeline(self.sp, "SOURce:POWer:LEVel?");
            resp = readline(self.sp);
            mW = str2double(strtrim(resp)) * 1000;
        end

        function disconnect(self)
            % disconnect  Disable emission and close serial port.
            try, self.setEnabled(false); catch, end
            if ~isempty(self.sp) && isvalid(self.sp)
                delete(self.sp);
            end
            self.sp = [];
        end
    end
end
