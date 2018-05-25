function ret = sideaxes(varargin)
% sideaxes Creates axes that shares an edge with an existing axes object
%   sideaxes(S) where S is 'north','east','south' or 'west' creates a new
%   axes graphics object relative to current axes object on the side
%   specified by S.
%
%   sideaxes(AX,...) creates the new axes object relative to axes AX
%
%   H = sideaxes(...) returns the axes object created.
%
%   sideaxes(...,Name,Value) specifies sideaxes properties using one or
%   more Name,Value pair arguments:
%   
%       gap - adds small gap between the edges of the axes in the units
%           defined by 'units'. Default: 0.
%       size - size (width or height) of the other edge, which was not
%           shared with the parent axes. By default, the new axes extends
%           all the way to the edge of the figure.
%       link - true (default) or false. If this setting is on, the
%           bordering axis of the parent and child axes objects will be the
%           same. They will have the same limits, scale (logarithmic or
%           linear) etc. When this setting is false, the newly create
%           child axes object will have limits of [0 1]. Callback functions 
%           make sure that the relationship is maintained.
%       orientation - 'relative' (default),'west','east','south' or 'north'
%           Defines how the created axes is oriented. Positive y-direction
%           is pointing to this direction. 'relative' means the orientation
%           is the same as S parameter.
%       units - 'normalized','inches','centimeters','points','pixels' or
%           'characters'. gap and size are defined in these units. Default:
%           'centimeters'
%
%   Any extra name-value pairs are passed forward to the axes command
%   called internally.
%
%   Example: visualize medians and quantiles on the edge of an
%   axes object.
%
%       x = randn(100,1)+0.5;                % synthesize data
%       y = randn(100,1);
%       axes('Position',[0.05 0.1 0.9 0.9]); % create main axes
%       plot(x,y,'.'); 
%       set(gca,'visible','off')             % disable matlab's own tick marks
%       sideaxes('south');                   % add sideaxes to south for ticks
%       tick(-5:5);                          % add custom tick marks
%       label(-5:5);                         % add custom labels for the tick marks
%       rangeline(min(x),quantile(x,0.25));  % show minimum and first quantile
%       plot(median(x),0,'k.','MarkerSize',10); % show median as a dot
%       label(median(x),[],@(x) sprintf('%.1f',x),'Clipping','off');
%       rangeline(quantile(x,0.75),max(x));  % third quantile  
%
%   See also tick, label, autotick.

    [ax,arg] = axescheck(varargin{:});

    if (isempty(ax))
        ax = gca;
    end
    fig = ancestor(ax,'figure');

    expectedSides = {'north','south','west','east'};
    expectedUnits = {'pixels','normalized','inches','centimeters','points','characters'};
    expectedOrientation = {'relative','west','east','south','north'};

    p = inputParser();
    p.KeepUnmatched = true;
    addRequired(p,'side',@(x) any(validatestring(x,expectedSides)));
    addParameter(p,'gap',0,@isnumeric);
    addParameter(p,'link',true);
    addParameter(p,'size',[],@(x) isempty(x) || isnumeric(x));
    addParameter(p,'units','centimeters',@(x) any(validatestring(x,expectedUnits)));
    addParameter(p,'orientation','relative',@(x) any(validatestring(x,expectedOrientation)));
    parse(p,arg{1},arg{2:end});

    mpn = getInUnits(ax,'Position','normalized');
    mpu = getInUnits(ax,'Position',p.Results.units);
    s = mpn(3:4) ./ mpu(3:4);
    size = p.Results.size;
    
    if strcmp(p.Results.side,'west')
        if (isempty(size))
            size = mpu(1)-p.Results.gap;
        end
        subpos = [(mpn(1)-s(1)*(p.Results.gap+size)) mpn(2) size*s(1) mpn(4)];
    elseif strcmp(p.Results.side,'east')
        if (isempty(size))
            size = 1/s(1)-mpu(1)-mpu(3)-p.Results.gap;
        end
        subpos = [(mpn(1)+mpn(3)+s(1)*p.Results.gap) mpn(2) size*s(1) mpn(4)];
    elseif strcmp(p.Results.side,'north')
        if (isempty(size))
            size = 1/s(2)-mpu(2)-mpu(4)-p.Results.gap;
        end
        subpos = [mpn(1) (mpn(2)+mpn(4)+s(2)*p.Results.gap) mpn(3) size*s(2)];
    else        
        if (isempty(size))
            size = mpu(2)-p.Results.gap;
        end
        subpos = [mpn(1) (mpn(2)-s(2)*(p.Results.gap+size)) mpn(3) size*s(2)];
    end
    
    d = [fieldnames(p.Unmatched) struct2cell(p.Unmatched)]';
    d = reshape(d,1,numel(d));
    ret = axes(fig,'Position',subpos,'units','normalized','visible','off','ClippingStyle','3dbox',d{:});    
    ret.UserData = p.Results.side;        
    
    hold on;
    
    orientation = p.Results.orientation;
    if strcmp(orientation,'relative')
        orientation = p.Results.side;
    end
        
    if strcmp(orientation,'west')
        ret.View = [-90 90];                     
    elseif strcmp(orientation,'east')
        ret.View = [90 90];                      
    elseif strcmp(orientation,'south')            
        ret.View = [180 90];        
    end           
        
    side = p.Results.side;
 
    if strcmp(side,'west') || strcmp(side,'east')
        otherInd = 1;
    else
        otherInd = 2;
    end
    
    otherlim = findAxis(ret,otherInd);
    
    ret.(otherlim) = [0 size];

    if p.Results.link
        callback();
        addlistener(ax,{'XLim','YLim','XScale','YScale','XDir','YDir','View'},'PostSet',@callback);        
    end
           
    function callback(~,~)               
        if strcmp(side,'west') || strcmp(side,'east')
            screenCordinateIndex = 2;
        else
            screenCordinateIndex = 1;
        end
                        
        [srclim,srcscale,srcdir,s1] = findAxis(ax,screenCordinateIndex);        
        [dstlim,dstscale,dstdir,s2] = findAxis(ret,screenCordinateIndex);
        
        flipped = s1 * s2 < 0;
              
        ret.(dstlim) = ax.(srclim);
        ret.(dstscale) = ax.(srcscale);  
        if flipped
            if strcmp(ax.(srcdir),'reverse')
                ret.(dstdir) = 'normal';
            else
                ret.(dstdir) = 'reverse';
            end
        else
            ret.(dstdir) = ax.(srcdir);
        end
    end
    
    function ret = getInUnits(ax,property,unitType)
        % In order to get a property of axes in specific units,
        % e.g. position, we have to change the units, then get the property
        % and finally restore the original units to leave it untouched.        
        oldUnits = get(ax,'Units');
        set(ax,'Units',unitType);
        ret = get(ax,property);
        set(ax,'Units',oldUnits);
    end

    function [lim,scale,dir,sgn] = findAxis(ax,screenCoordinateIndex)
        axview = ax.View;
        v = viewmtx(axview(1),axview(2));
        [~,ind] = max(abs(v(screenCoordinateIndex,1:3)));
        prefixes = 'XYZ';
        prefix = prefixes(ind);
        [lim,scale,dir] = deal([prefix 'Lim'],[prefix 'Scale'],[prefix 'Dir']);
        sgn = sign(v(screenCoordinateIndex,ind));
    end
end
