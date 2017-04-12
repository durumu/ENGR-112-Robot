clear variables;

% Initialize data
% ===========================================

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

rotations = [32,0,20,-12,10,-22,-32,-45,45,45,45,45,45];

cr_rgb = load('eabc_rgb.txt');

rgbfile = fopen('eabc_rgb.txt','a');

linenumber = size(cr_rgb,1)+1;

marbles_sorted = zeros(1,8);
marbles_needed = zeros(1,8);

consecutive_nothing = 0;

current_code = [];
codes_processed = 0;

% Initialize ev3s e and f
% ===========================================

e = legoev3('usb');
f = legoev3('bt','00165344db01');

color_reader = colorSensor(e);
gate_motor = motor(e,'A');
dispenser_motor = motor(e,'B');
sort_motor = motor(e,'C');

barcode_reader = colorSensor(f);
knock_motor = motor(f,'A');
belt_motor = motor(f,'B');
barcode_motor = motor(f,'C');


starting_sort_rotation = readRotation(sort_motor);
starting_dispenser_rotation = readRotation(belt_motor);

% Sort all the marbles
% ============================================

sorting = true;
while sorting
    
    % run the dispenser for 1 marble worth of rotation
    starting_dispenser_rotation = readRotation(dispenser_motor);
    rotation_amount = 97; %97 degrees is the amount to rotate for 1 marble
    while (readRotation(dispenser_motor) > (starting_dispenser_rotation-97))
        dispenser_motor.Speed = -40;
        dispenser_motor.start();
        pause(.01);
        dispenser_motor.stop();
    end
   
    % wait for the marble to hit color reader area
    pause(2);
    
    % get and print color from the color reader
    [r, g, b] = read_rgb(color_reader);
    fprintf('R: %03d, G: %03d, B: %03d\n',r,g,b);
    
    closest = -2; %identity of closest marble
    closest_distance = inf; %the length of the smallest rgb vector
    
    % attempt to identify marble by finding marble most similar in cr_rgb
    [closest, closest_distance] = find_closest(r,g,b,cr_rgb);
    
    fprintf('%s\n',types(closest,:));
    
    if (closest_distance > 5)
        % we have new data so we will write it to the main file.
        fprintf('Faraway read! (type %d, %d away, line #%d)\n',closest,closest_distance,linenumber);
        fprintf(rgbfile,'%03d, %03d, %03d, %d;\n',r,g,b,closest); %write new data to file
        cr_rgb = [cr_rgb; r g b closest];
        linenumber = linenumber + 1;
        beep(e); % alert us of faraway read
    end
    
    if (closest < 13) 
        % identified as a marble, not as nothing, so the streak is broken
        consecutive_nothing = 0;
        
        if (closest <= 8)
            % one of the marbles we are looking for, increment its position
            % in marbles_sorted
            marbles_sorted(closest) = marbles_sorted(closest) + 1;
        end
        
        % move the sorting motor to the right position
        current_point = readRotation(sort_motor);
        while (abs(current_point-(rotations(closest)+starting_sort_rotation)) >= 2)
            current_point = readRotation(sort_motor);
            if ((rotations(closest)+starting_sort_rotation) < current_point)
                sort_motor.Speed = -2;
            else
                sort_motor.Speed = 2;
            end
            sort_motor.start()
            pause(.05);
            sort_motor.stop();
        end
        
        % open the floodgates!
        open_gate(gate_motor);
    elseif sum(marbles_sorted) > 5 % we might be done sorting if we get a nothing in the middle
        consecutive_nothing = consecutive_nothing + 1;
        if (consecutive_nothing == 3) % if we got 3 nothing in a row
            open_gate(gate_motor);
        elseif consecutive_nothing > 3
            sorting = false; % we are done sorting
        end
    end
    
end

fprintf('DONE SORTING!!\n');

% Process all the bar codes
% ============================================

while true
    color = readColorRGB(br);
    fprintf('R:%03d G:%03d B:%03d\n',color(1),color(2),color(3));
    
    closest = -2; %identity of closest
    closest_distance = inf; %closest distance
    
    for i=1:size(barcode_rgb,1)
        distance = (color(1)-barcode_rgb(i,1))^2 + (color(2)-barcode_rgb(i,2))^2 + (color(3)-barcode_rgb(i,3))^2;
        if distance < closest_distance
            closest = barcode_rgb(i,4);
            closest_distance = distance;
        end
    end
    
    disp(closest);
    
    if closest >= 0
        current_code = [current_code num2str(closest)];
    elseif numel(current_code) > 8
        first = find(current_code=='1',1);
        fprintf('%s\n',current_code(first+1:numel(current_code)));
        [d1, d2] = decode(current_code);
        
        fprintf('%s x%d\n%s x%d\n',types(d1.t,:),d1.q,types(d2.t,:),d2.q);
        counts(d1.t) = counts(d1.t) + d1.q;
        counts(d2.t) = counts(d2.t) + d2.q;
        
        current_code = [];
        
        codes = codes + 1;
        if codes == 4
            break
        end
    else
        current_code = [];
    end
    
    %run motor
    
    brm.Speed = -90;
    brm.start();
    pause(.202);
    brm.stop(1);
    
    pause(2);
end

fprintf('\nFINAL COUNTS\n================\n');

for i=1:13
    if counts(i) > 0
        fprintf('%s x%d\n',types(i,:),counts(i));
    end
end