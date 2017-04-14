clear variables;

types = [
    'large white glass '; % 1
    'small white glass '; % 2
    'large red glass   '; % 3
    'small red glass   '; % 4
    'large blue glass  '; % 5
    'small blue glass  '; % 6
    'steel             '; % 7
    'HDPE plastic      '; % 8
    'large yellow glass'; % 9
    'small yellow glass'; %10
    'large green glass '; %11
    'small green glass '; %12
    'nothing           '];%13


barcode_rgb = [
    300,300,250, 0;
     58, 69, 42, 1;
     45, 45, 34, 1;
    120,140, 100,-1];
    
counts = zeros(1,8);
codes = 0;

e = legoev3('usb');

barcode_reader = colorSensor(e); 
knock_motor = motor(e,'A'); 
belt_motor = motor(e,'B'); 
barcode_motor = motor(e,'C'); 

current_code = [];

starting_belt_rotation = readRotation(belt_motor); 
starting_knock_rotation = readRotation(knock_motor); 

% Process all the bar codes
% ============================================

processing_codes = true;
while processing_codes
    [r, g, b] = read_rgb(barcode_reader);
    fprintf('R: %03d, G: %03d, B: %03d\n',r,g,b);
    
    [closest_br, closest_distance_br] = find_closest(r,g,b,barcode_rgb);
    
    disp(closest_br);
    
    if closest_br >= 0
        current_code = [current_code num2str(closest_br)];
    elseif numel(current_code) > 8
        %first = find(current_code=='1',1);
        %fprintf('%s\n',current_code(first+1:numel(current_code)));
        [d1, d2] = decode(current_code);
        
        % print the amount of each marble needed for debug reasons
        fprintf('%s x%d\n%s x%d\n',types(d1.t,:),d1.q,types(d2.t,:),d2.q);
        
        % update the amount of marbles needed with new quantities
        marbles_needed(d1.t) = marbles_needed(d1.t) + d1.q;
        marbles_needed(d2.t) = marbles_needed(d2.t) + d2.q;
        
        current_code = [];
        
        codes = codes + 1;
        if codes == 4
            processing_codes = false;
        end
    else
        current_code = [];
    end
    
    %run barcode motor
    if processing_codes
        run_motor(barcode_motor,-90,.202);
        pause(2);
    end
end

fprintf('DONE PROCESSING BAR CODES\nFINAL COUNTS:\n');

for i=1:8
    if marbles_needed(i) > 0
        fprintf('%s x%d\n',types(i,:),marbles_needed(i));
    end
end

% TODO -- Dispense the marbles...
% ============================================