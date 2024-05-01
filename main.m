function [V] = STL_to_Mesh(STLin, resolution)
    V = VOXELISE(resolution,resolution,resolution,STLin)
end 
    
function [error] = small_feature_detection(V,tau)
	%Create the flipped version of V to detect negative space thin 
    %features
    [x y z] = size(V);
    V_flip = zeroes(x, y, z); %creating complementary array
    V_flip(V==0) = 1; %all 0’s are flipped to 1’s, and the 1’s flipped %to 0’s are already taken care of by the default

    %top hat transform, which is dilation and then erosion with unit 
    %ball scaled by tau, then subtraction from original image
    %hat transform
    tau_ball = strel("sphere",tau);
    pos_space_smalls = imtophat(V, tau_ball);
    neg_space_smalls = imtophat(V_flip, tau_ball);

    %not all of the detected too-small features are actually relevant 
    %for example, sharp corners may be slightly rounded but that’s %okay! So plot them to show
    voxelPlot(V, 'AxisTight', true, 'Color', [0 0 0.1], 'Transparency', 0.5) %semi transparent plot of all voxels
    hold on 

    voxelPlot(pos_space_smalls, ‘AxisTight,’ true, ‘Color’, [1 0 0], ‘Transparency’, 0.75)
    hold on

    voxelPlot(pos_space_smalls, ‘AxisTight,’ true, ‘Color’, [0 1 0], ‘Transparency’, 0.75)
    error = pos_space_smalls + neg_space_smalls
end

function rotatedV = rotateVoxelObject(V, axis, angle)
    % Check if the input axis is valid
    if ~ismember(axis, {'x', 'y', 'z'})
        error('Invalid rotation axis. Use ''x'', ''y'', or ''z''.');
    end
        
    % Define the rotation axis for imrotate3
    if axis == ‘x’
        rotAxis = [1, 0, 0];
    elseif axis == ‘y’
        rotAxis = [0, 1, 0];
    else
        rotAxis = [0, 0, 1];
    end
    
    % Perform the rotation using imrotate3
    % 'nearest' and 'crop' options are used to avoid changing the size of the matrix and to use nearest neighbor interpolation
    rotatedV = imrotate3(V, angle, rotAxis, 'nearest', 'crop');
    voxelPlot(rotateV, 'AxisTight', true, 'Color', [0 0 0.1], 'Transparency', 0.5) %semi transparent plot of all voxels
end

function YAML = Voxel_to_YAML_STL(voxel_data, file_name): 
	
	% DEFINE FILE NAME
    file_name_yaml = file_name’.yaml';
    file_name_stl = file_name’.stl’

        %CONVERT VOXEL TO MESH
    mesh_data = isosurface(voxelData, 0.5) 
    mesh_yaml.vertices = mesh_data.vertices;
    mesh_yaml.faces = mesh_data.faces;

    % CONVERT YAML TO YAML
    [x_dim, y_dim, z_dim] = size(V);
    voxel_data.dimensions.x_dim = x_dim;
    voxel_data.dimensions.y_dim = y_dim;
    voxel_data.dimensions.z_dim = z_dim;
    voxel_data.data = base64encode(voxel_data);

    % Combine into a single data structure
    data = struct('file_info', struct('name', 'example_file', 'extension', 'stl'), ...
                'raw_data', struct('voxel_data', voxel_data, 'mesh_data', mesh_data));

    % WRITE TO YAML file
    yaml_write(file_name_yaml, data);
    % WRITE TO STL
    stlwrite(fie_name_stl, mesh_data); % Export mesh to STL file
end

    