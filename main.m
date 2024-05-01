
%Functions we're writing: 

%STL_to_Mesh: Christine
%Input: STL file, resolution (how many voxels to break the object into)
%Output: voxel object
function [V] = STL_to_Mesh(STLin, resolution)
	V = VOXELISE(resolution,resolution,resolution,STLin)
end 

%Small_feature_detection: June
%Input: voxelized object O, tolerance of printer
%Output: Outputs the voxels that are in thin features. Displays any features that are too small (red for positive space features, green for negative space). Integrate so that user can decide if they want to proceed or not after seeing image

function [error] = small_feature_detection(V,tau)
	%Create the flipped version of V to detect negative space thin features
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
	voxelPlot(V, 'AxisTight', true, 'Color', [0 0 0.1], 'Transparency', 0.5) %semi transparent plot of all voxels %THIS IS WRONG INPUT FOR SOME REASON
	hold on 
	%voxelPlot(pos_space_smalls, ‘AxisTight,’ true, ‘Color’, [1 0 0], ‘Transparency’, 0.75) THIS IS DEF WRONG INPUT
	%hold on
	%voxelPlot(pos_space_smalls, ‘AxisTight,’ true, ‘Color’, [0 1 0], ‘Transparency’, 0.75) THIS IS DEF WRONG INPUT
	error = pos_space_smalls + neg_space_smalls
end
	
%Rotate: Christine
%Input: voxelized object O, name of axis of rotation, angle of rotation
%Output: new voxelized object that is rotated version of original
%Pretty simple matrix rotation
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
    Else
        rotAxis = [0, 0, 1];
    end

    % Perform the rotation using imrotate3
    % 'nearest' and 'crop' options are used to avoid changing the size of the matrix and to use nearest neighbor interpolation
    rotatedV = imrotate3(V, angle, rotAxis, 'nearest', 'crop');
    voxelPlot(rotateV, 'AxisTight', true, 'Color', [0 0 0.1], 'Transparency', 0.5) %semi transparent plot of all voxels %THIS IS WRONG INPUT FOR SOME REASON
    hold on 
end

%Space_of_support: June
%Input: voxelized object in orientation we are trying to print
%Output: space that support material would take up (bounding volume it occupies, just assume takes up full space for comparison purposes) 
%Use the math from Will it Print- normal vector nf of each facet of interest (checking multiple facets). The build vector B is perp to the build plate (orthogonal to layers). 𝛉 is the angle between them, for FDM support material is needed beneath a certain facet if its 𝛉 is greater than some threshold, usually 135 degrees. Find vol under

function support = space_of_support(V, thres_angle)
	meshdataIN = isosurface(V); %not sure if this is correct
	[coordNORMALS] = COMPUTE_mesh_normals(meshdataIN);
	build_dir = [0 0 1] %normal vector to build plate
	count = 1
	[r c] = size(coordNORMALS);
	for i = 1:r
		norm_vector = coordNORMALS(i,:);
		theta = atan2(norm(cross(norm_vector,build_dir)), dot(norm_vector,build_dir));
		if theta >= thres_angle
			count = count + 1;
		end 
	end
	support = count
 end
			
%Voxel_to_STL: Spring
%Input: voxel object
%Output: STL file 
%Convert the voxel to mesh to turn into STL
%The isovalue is essentially the contour value or threshold that you wish to impose

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

%YAML_paired_STL: Spring
%Input: STL
%Output: YMAL with FEA stuff
%For now output the bare voxel data and the bare mesh data corresponding to the STL

%Existing functions we’re borrowing:

%Voxelizing
function [varargout] = CONVERT_meshformat(varargin)
%CONVERT_meshformat  Convert mesh data from array to faces,vertices format or vice versa
%==========================================================================
% AUTHOR        Adam H. Aitkenhead
% CONTACT       adam.aitkenhead@christie.nhs.uk
% INSTITUTION   The Christie NHS Foundation Trust
%
% USAGE         [faces,vertices] = CONVERT_meshformat(meshXYZ)
%         or... [meshXYZ]        = CONVERT_meshformat(faces,vertices)
%
% IN/OUTPUTS    meshXYZ  - Nx3x3 array - An array defining the vertex
%                          positions for each of the N facets, with:
%                            1 row for each facet
%                            3 cols for the x,y,z coordinates
%                            3 pages for the three vertices
%
%               vertices - Nx3 array   - A list of the x,y,z coordinates of
%                          each vertex in the mesh.
%
%               faces    - Nx3 array   - A list of the vertices used in
%                          each facet of the mesh, identified using the row
%                          number in the array vertices.
%==========================================================================
%==========================================================================
% VERSION  USER  CHANGES
% -------  ----  -------
% 100817   AHA   Original version
% 111104   AHA   Housekeeping tidy-up.
%==========================================================================
if nargin==2 && nargout==1
 faces  = varargin{1};
 vertex = varargin{2};
 
 meshXYZ = zeros(size(faces,1),3,3);
 for loopa = 1:size(faces,1)
   meshXYZ(loopa,:,1) = vertex(faces(loopa,1),:);
   meshXYZ(loopa,:,2) = vertex(faces(loopa,2),:);
   meshXYZ(loopa,:,3) = vertex(faces(loopa,3),:);
 end
 varargout(1) = {meshXYZ};
 
elseif nargin==1 && nargout==2
 meshXYZ = varargin{1};
  vertices = [meshXYZ(:,:,1);meshXYZ(:,:,2);meshXYZ(:,:,3)];
 vertices = unique(vertices,'rows');
 faces = zeros(size(meshXYZ,1),3);
 for loopF = 1:size(meshXYZ,1)
   for loopV = 1:3
      
     %[C,IA,vertref] = intersect(meshXYZ(loopF,:,loopV),vertices,'rows');
     %The following 3 lines are equivalent to the previous line, but are much faster:
    
     vertref = find(vertices(:,1)==meshXYZ(loopF,1,loopV));
     vertref = vertref(vertices(vertref,2)==meshXYZ(loopF,2,loopV));
     vertref = vertref(vertices(vertref,3)==meshXYZ(loopF,3,loopV));
    
     faces(loopF,loopV) = vertref;
    
   end
 end
  varargout(1) = {faces};
 varargout(2) = {vertices};
 
end
end %function
%==========================================================================

function [coordVERTICES,varargout] = READ_stl(stlFILENAME,varargin)
% READ_stlascii  Read mesh data in the form of an <*.stl> file
%==========================================================================
% FILENAME:          READ_stl.m
% AUTHOR:            Adam H. Aitkenhead
% INSTITUTION:       The Christie NHS Foundation Trust
% CONTACT:           adam.aitkenhead@physics.cr.man.ac.uk
% DATE:              29th March 2010
% PURPOSE:           Read mesh data in the form of an <*.stl> file.
%
% USAGE:
%
%     [coordVERTICES,coordNORMALS,stlNAME] = READ_stl(stlFILENAME,stlFORMAT)
%
% INPUT PARAMETERS:
%
%     stlFILENAME   - String - Mandatory - The filename of the STL file.
%
%     stlFORMAT     - String - Optional  - The format of the STL file:
%                                        'ascii' or 'binary'
%
% OUTPUT PARAMETERS:
%
%     coordVERTICES - Nx3x3 array - Mandatory
%                                 - An array defining the vertex positions
%                                   for each of the N facets, with:
%                                   1 row for each facet
%                                   3 cols for the x,y,z coordinates
%                                   3 pages for the three vertices
%
%     coordNORMALS  - Nx3 array   - Optional
%                                 - An array defining the normal vector for
%                                   each of the N facets, with:
%                                   1 row for each facet
%                                   3 cols for the x,y,z components of the vector
%
%     stlNAME       - String      - Optional  - The name of the STL object.
%
%==========================================================================
%==========================================================================
% VERSION  USER  CHANGES
% -------  ----  -------
% 100329   AHA   Original version
% 100513   AHA   Totally reworked the code.  Now use textscan to read the
%                file all at once, rather than one line at a time with
%                fgetl.  Major speed improvment.
% 100623   AHA   Combined code which reads ascii STLS and code which reads
%                binary STLs into a single function.
% 101126   AHA   Small change to binary read code:  Now use fread instead
%                of fseek.  Gives large speed increase.
%==========================================================================
%==========================================================================
% STL ascii file format
%======================
% ASCII STL files have the following structure.  Technically each facet
% could be any 2D shape, but in practice only triangular facets tend to be
% used.  The present code ONLY works for meshes composed of triangular
% facets.
%
% solid object_name
% facet normal x y z
%   outer loop
%     vertex x y z
%     vertex x y z
%     vertex x y z
%   endloop
% endfacet
%
% <Repeat for all facets...>
%
% endsolid object_name
%==========================================================================
%==========================================================================
% STL binary file format
%=======================
% Binary STL files have an 84 byte header followed by 50-byte records, each
% describing a single facet of the mesh.  Technically each facet could be
% any 2D shape, but that would screw up the 50-byte-per-facet structure, so
% in practice only triangular facets are used.  The present code ONLY works
% for meshes composed of triangular facets.
%
% HEADER:
% 80 bytes:  Header text
% 4 bytes:   (int) The number of facets in the STL mesh
%
% DATA:
% 4 bytes:  (float) normal x
% 4 bytes:  (float) normal y
% 4 bytes:  (float) normal z
% 4 bytes:  (float) vertex1 x
% 4 bytes:  (float) vertex1 y
% 4 bytes:  (float) vertex1 z
% 4 bytes:  (float) vertex2 x
% 4 bytes:  (float) vertex2 y
% 4 bytes:  (float) vertex2 z
% 4 bytes:  (float) vertex3 x
% 4 bytes:  (float) vertex3 y
% 4 bytes:  (float) vertex3 z
% 2 bytes:  Padding to make the data for each facet 50-bytes in length
%   ...and repeat for next facet...
%==========================================================================
if nargin==2
 stlFORMAT = lower(varargin{1});
else
 stlFORMAT = 'auto';
end
%If necessary, identify whether the STL is ascii or binary:
if strcmp(stlFORMAT,'ascii')==0 && strcmp(stlFORMAT,'binary')==0
 stlFORMAT = IDENTIFY_stl_format(stlFILENAME);
end
%Load the STL file:
if strcmp(stlFORMAT,'ascii')
 [coordVERTICES,coordNORMALS,stlNAME] = READ_stlascii(stlFILENAME);
elseif strcmp(stlFORMAT,'binary')
 [coordVERTICES,coordNORMALS] = READ_stlbinary(stlFILENAME);
 stlNAME = 'unnamed_object';
end %if
%Prepare the output arguments
if nargout == 2
 varargout(1) = {coordNORMALS};
elseif nargout == 3
 varargout(1) = {coordNORMALS};
 varargout(2) = {stlNAME};
end
end %function
%==========================================================================
function [stlFORMAT] = IDENTIFY_stl_format(stlFILENAME)
% IDENTIFY_stl_format  Test whether an stl file is ascii or binary
% Open the file:
fidIN = fopen(stlFILENAME);
% Check the file size first, since binary files MUST have a size of 84+(50*n)
fseek(fidIN,0,1);         % Go to the end of the file
fidSIZE = ftell(fidIN);   % Check the size of the file
if rem(fidSIZE-84,50) > 0
  
 stlFORMAT = 'ascii';
else
 % Files with a size of 84+(50*n), might be either ascii or binary...
  
 % Read first 80 characters of the file.
 % For an ASCII file, the data should begin immediately (give or take a few
 % blank lines or spaces) and the first word must be 'solid'.
 % For a binary file, the first 80 characters contains the header.
 % It is bad practice to begin the header of a binary file with the word
 % 'solid', so it can be used to identify whether the file is ASCII or
 % binary.
 fseek(fidIN,0,-1);        % Go to the start of the file
 firsteighty = char(fread(fidIN,80,'uchar')');
 % Trim leading and trailing spaces:
 firsteighty = strtrim(firsteighty);
 % Take the first five remaining characters, and check if these are 'solid':
 firstfive = firsteighty(1:min(5,length(firsteighty)));
 % Double check by reading the last 80 characters of the file.
 % For an ASCII file, the data should end (give or take a few
 % blank lines or spaces) with 'endsolid <object_name>'.
 % If the last 80 characters contains the word 'endsolid' then this
 % confirms that the file is indeed ASCII.
 if strcmp(firstfive,'solid')
    fseek(fidIN,-80,1);     % Go to the end of the file minus 80 characters
   lasteighty = char(fread(fidIN,80,'uchar')');
    if findstr(lasteighty,'endsolid')
     stlFORMAT = 'ascii';
   else
     stlFORMAT = 'binary';
   end
  else
   stlFORMAT = 'binary';
 end
 end
% Close the file
fclose(fidIN);
end %function
%==========================================================================
%==========================================================================
function [coordVERTICES,coordNORMALS,stlNAME] = READ_stlascii(stlFILENAME)
% READ_stlascii  Read mesh data in the form of an ascii <*.stl> file
% Read the ascii STL file
fidIN = fopen(stlFILENAME);
fidCONTENTcell = textscan(fidIN,'%s','delimiter','\n');                  %Read all the file
fidCONTENT = fidCONTENTcell{:}(logical(~strcmp(fidCONTENTcell{:},'')));  %Remove all blank lines
fclose(fidIN);
% Read the STL name
if nargout == 3
 line1 = char(fidCONTENT(1));
 if (size(line1,2) >= 7)
   stlNAME = line1(7:end);
 else
   stlNAME = 'unnamed_object';
 end
end
% Read the vector normals
if nargout >= 2
 stringNORMALS = char(fidCONTENT(logical(strncmp(fidCONTENT,'facet normal',12))));
 coordNORMALS  = str2num(stringNORMALS(:,13:end));
end
% Read the vertex coordinates
facetTOTAL       = sum(strcmp(fidCONTENT,'endfacet'));
stringVERTICES   = char(fidCONTENT(logical(strncmp(fidCONTENT,'vertex',6))));
coordVERTICESall = str2num(stringVERTICES(:,7:end));
cotemp           = zeros(3,facetTOTAL,3);
cotemp(:)        = coordVERTICESall;
coordVERTICES    = shiftdim(cotemp,1);
end %function
%==========================================================================
%==========================================================================
function [coordVERTICES,coordNORMALS] = READ_stlbinary(stlFILENAME)
% READ_stlbinary  Read mesh data in the form of an binary <*.stl> file
% Open the binary STL file
fidIN = fopen(stlFILENAME);
% Read the header
fseek(fidIN,80,-1);                   % Move to the last 4 bytes of the header
facetcount = fread(fidIN,1,'int32');  % Read the number of facets in the stl file
% Initialise arrays into which the STL data will be loaded:
coordNORMALS  = zeros(facetcount,3);
coordVERTICES = zeros(facetcount,3,3);
% Read the data for each facet:
for loopF = 1:facetcount
  tempIN = fread(fidIN,3*4,'float');
  coordNORMALS(loopF,1:3)    = tempIN(1:3);    % x,y,z components of the facet's normal vector
 coordVERTICES(loopF,1:3,1) = tempIN(4:6);    % x,y,z coordinates of vertex 1
 coordVERTICES(loopF,1:3,2) = tempIN(7:9);    % x,y,z coordinates of vertex 2
 coordVERTICES(loopF,1:3,3) = tempIN(10:12);  % x,y,z coordinates of vertex 3
  fread(fidIN,1,'int16');   % Move to the start of the next facet.  Using fread is much quicker than using fseek(fidIN,2,0);
end %for
% Close the binary STL file
fclose(fidIN);
end %function
%==========================================================================

function [gridOUTPUT,varargout] = VOXELISE(gridX,gridY,gridZ,varargin)
% VOXELISE  Voxelise a 3D triangular-polygon mesh.
%==========================================================================
% AUTHOR        Adam H. Aitkenhead
% CONTACT       adam.aitkenhead@christie.nhs.uk
% INSTITUTION   The Christie NHS Foundation Trust
%
% USAGE        [gridOUTPUT,gridCOx,gridCOy,gridCOz] = VOXELISE(gridX,gridY,gridZ,STLin,raydirection)
%        or... [gridOUTPUT,gridCOx,gridCOy,gridCOz] = VOXELISE(gridX,gridY,gridZ,meshFV,raydirection)
%        or... [gridOUTPUT,gridCOx,gridCOy,gridCOz] = VOXELISE(gridX,gridY,gridZ,meshX,meshY,meshZ,raydirection)
%        or... [gridOUTPUT,gridCOx,gridCOy,gridCOz] = VOXELISE(gridX,gridY,gridZ,meshXYZ,raydirection)
%
% INPUTS
%
%     gridX   - Mandatory - 1xP array     - List of the grid X coordinates.
%                           OR an integer - Number of voxels in the grid in the X direction.
%
%     gridY   - Mandatory - 1xQ array     - List of the grid Y coordinates.
%                           OR an integer - Number of voxels in the grid in the Y direction.
%
%     gridZ   - Mandatory - 1xR array     - List of the grid Z coordinates.
%                           OR an integer - Number of voxels in the grid in the Z direction.
%
%     STLin   - Optional  - string        - Filename of the STL file.
%
%     meshFV  - Optional  - structure     - Structure containing the faces and vertices
%                                           of the mesh, in the same format as that produced
%                                           by the isosurface command.
%
%     meshX   - Optional  - 3xN array     - List of the mesh X coordinates for the 3 vertices of each of the N triangular patches
%     meshY   - Optional  - 3xN array     - List of the mesh Y coordinates for the 3 vertices of each of the N triangular patches
%     meshZ   - Optional  - 3xN array     - List of the mesh Z coordinates for the 3 vertices of each of the N triangular patches
%
%     meshXYZ - Optional  - Nx3x3 array   - The vertex coordinates for each facet, with:
%                                           1 row for each facet
%                                           3 columns for the x,y,z coordinates
%                                           3 pages for the three vertices
%
%     raydirection - Optional - String    - Defines the directions in which ray-tracing
%                                           is performed.  The default is 'xyz', which
%                                           traces in the x,y,z directions and combines
%                                           the results.
%
% OUTPUTS
%
%     gridOUTPUT - Mandatory - PxQxR logical array - Voxelised data (1=>Inside the mesh, 0=>Outside the mesh)
%
%     gridCOx    - Optional - 1xP array - List of the grid X coordinates.
%     gridCOy    - Optional - 1xQ array - List of the grid Y coordinates.
%     gridCOz    - Optional - 1xR array - List of the grid Z coordinates.
%
% EXAMPLES
%
%     To voxelise an STL file:
%     >>  [gridOUTPUT] = VOXELISE(gridX,gridY,gridZ,STLin)
%
%     To voxelise a mesh defined by a structure containing the faces and vertices:
%     >>  [gridOUTPUT] = VOXELISE(gridX,gridY,gridZ,meshFV)
%
%     To voxelise a mesh where the x,y,z coordinates are defined by three 3xN arrays:
%     >>  [gridOUTPUT] = VOXELISE(gridX,gridY,gridZ,meshX,meshY,meshZ)
%
%     To voxelise a mesh defined by a single Nx3x3 array:
%     >>  [gridOUTPUT] = VOXELISE(gridX,gridY,gridZ,meshXYZ)
%
%     To also output the lists of X,Y,Z coordinates:
%     >>  [gridOUTPUT,gridCOx,gridCOy,gridCOz] = VOXELISE(gridX,gridY,gridZ,STLin)
%
%     To use ray-tracing in only the z-direction:
%     >>  [gridOUTPUT] = VOXELISE(gridX,gridY,gridZ,STLin,'z')
%
% NOTES
%
%   - The mesh must be properly closed (ie. watertight).
%   - Defining raydirection='xyz' means that the mesh is ray-traced in each
%     of the x,y,z directions, with the overall result being a combination
%     of the result from each direction.  This gives the most reliable
%     result at the expense of computation time.
%   - Tracing in only one direction (eg. raydirection='z') is faster, but
%     can potentially lead to artefacts where a ray exactly crosses
%     several facet edges.
%
% REFERENCES
%
%   - This code uses a ray intersection method similar to that described by:
%     Patil S and Ravi B.  Voxel-based representation, display and
%     thickness analysis of intricate shapes. Ninth International
%     Conference on Computer Aided Design and Computer Graphics (CAD/CG
%     2005)
%==========================================================================
%==========================================================================
% VERSION USER CHANGES
% ------- ---- -------
% 100510  AHA  Original version.
% 100514  AHA  Now works with non-STL input.  Changes also provide a
%              significant speed improvement.
% 100520  AHA  Now optionally output the grid x,y,z coordinates.
%              Robustness also improved.
% 100614  AHA  Define gridOUTPUT as a logical array to improve memory
%              efficiency.
% 100615  AHA  Reworked the ray interpolation code to correctly handle
%              logical arrays.
% 100623  AHA  Enable ray-tracing in any combination of the x,y,z
%              directions.
% 100628  AHA  Allow input to be a structure containing [faces,vertices]
%              data, similar to the type of structure output by
%              isosurface.
% 100907  AHA  Now allow the grid to be smaller than the mesh dimensions.
% 101126  AHA  Simplified code, slight speed improvement, more robust.
%              Changed handling of automatic grid generation to reduce
%              chance of artefacts.
% 101201  AHA  Fixed bug in automatic grid generation.
% 110303  AHA  Improved method of finding which mesh facets can possibly
%              be crossed by each ray.  Up to 80% reduction in run-time.
% 111104  AHA  Housekeeping tidy-up.
% 130212  AHA  Added checking of ray/vertex intersections, which reduces
%              artefacts in situations where the mesh vertices are located
%              directly on ray paths in the voxelisation grid.
%==========================================================================
%======================================================
% CHECK THE REQUIRED NUMBER OF OUTPUT PARAMETERS
%======================================================
if nargout~=1 && nargout~=4
 error('Incorrect number of output arguments.')
end
%======================================================
% READ INPUT PARAMETERS
%======================================================
% Read the ray direction if defined by the user, and remove this from the
% list of input arguments.  This makes it to make it easier to extract the
% mesh data from the input arguments in the subsequent step.
if ischar(varargin{end}) && max(strcmpi(varargin{end},{'x','y','z','xy','xz','yx','yz','zx','zy','xyz','xzy','yxz','yzx','zxy','zyx'}))
 raydirection    = lower(varargin{end});
 varargin        = varargin(1:nargin-4);
 narginremaining = nargin-1;
else
 raydirection    = 'xyz';    %Set the default value if none is defined by the user
 narginremaining = nargin;
end
% Whatever the input mesh format is, it is converted to an Nx3x3 array
% defining the vertex positions for each facet, with 1 row for each facet,
% 3 cols for the x,y,z coordinates, and 3 pages for the three vertices.
if narginremaining==4
  if isstruct(varargin{1})==1
   meshXYZ = CONVERT_meshformat(varargin{1}.faces,varargin{1}.vertices);
  elseif ischar(varargin{1})
   meshXYZ = READ_stl(varargin{1});
  
 else
   meshXYZ = varargin{1};
  
 end
elseif narginremaining==6
 meshX = varargin{1};
 meshY = varargin{2};
 meshZ = varargin{3};
 meshXYZ = zeros( size(meshX,2) , 3 , size(meshX,1) );
 meshXYZ(:,1,:) = reshape(meshX',size(meshX,2),1,3);
 meshXYZ(:,2,:) = reshape(meshY',size(meshY,2),1,3);
 meshXYZ(:,3,:) = reshape(meshZ',size(meshZ,2),1,3);
 else
  error('Incorrect number of input arguments.')
 end
%======================================================
% IDENTIFY THE MIN AND MAX X,Y,Z COORDINATES OF THE POLYGON MESH
%======================================================
meshXmin = min(min(meshXYZ(:,1,:)));
meshXmax = max(max(meshXYZ(:,1,:)));
meshYmin = min(min(meshXYZ(:,2,:)));
meshYmax = max(max(meshXYZ(:,2,:)));
meshZmin = min(min(meshXYZ(:,3,:)));
meshZmax = max(max(meshXYZ(:,3,:)));
%======================================================
% CHECK THE DIMENSIONS OF THE 3D OUTPUT GRID
%======================================================
% The output grid will be defined by the coordinates in gridCOx, gridCOy, gridCOz
if numel(gridX)>1
 if size(gridX,1)>size(gridX,2)   %gridX should be a row vector rather than a column vector
   gridCOx = gridX';
 else
   gridCOx = gridX;
 end
elseif numel(gridX)==1 && gridX==1   %If gridX is a single integer (rather than a vector) and is equal to 1
 gridCOx   = (meshXmin+meshXmax)/2;
elseif numel(gridX)==1 && rem(gridX,1)==0   %If gridX is a single integer (rather than a vector) then automatically create the list of x coordinates
 voxwidth  = (meshXmax-meshXmin)/(gridX+1/2);
 gridCOx   = meshXmin+voxwidth/2 : voxwidth : meshXmax-voxwidth/2;
end
if numel(gridY)>1
 if size(gridY,1)>size(gridY,2)   %gridY should be a row vector rather than a column vector
   gridCOy = gridY';
 else
   gridCOy = gridY;
 end
elseif numel(gridY)==1 && gridY==1   %If gridX is a single integer (rather than a vector) and is equal to 1
 gridCOy   = (meshYmin+meshYmax)/2;
elseif numel(gridY)==1 && rem(gridY,1)==0   %If gridX is a single integer (rather than a vector) then automatically create the list of y coordinates
 voxwidth  = (meshYmax-meshYmin)/(gridY+1/2);
 gridCOy   = meshYmin+voxwidth/2 : voxwidth : meshYmax-voxwidth/2;
end
if numel(gridZ)>1
 if size(gridZ,1)>size(gridZ,2)   %gridZ should be a row vector rather than a column vector
   gridCOz = gridZ';
 else
   gridCOz = gridZ;
 end
elseif numel(gridZ)==1 && gridZ==1   %If gridX is a single integer (rather than a vector) and is equal to 1
 gridCOz   = (meshZmin+meshZmax)/2;
elseif numel(gridZ)==1 && rem(gridZ,1)==0   %If gridZ is a single integer (rather than a vector) then automatically create the list of z coordinates
 voxwidth  = (meshZmax-meshZmin)/(gridZ+1/2);
 gridCOz   = meshZmin+voxwidth/2 : voxwidth : meshZmax-voxwidth/2;
end
%Check that the output grid is large enough to cover the mesh:
if ~isempty(strfind(raydirection,'x'))  &&  (min(gridCOx)>meshXmin || max(gridCOx)<meshXmax)
 gridcheckX = 0;
 if min(gridCOx)>meshXmin
   gridCOx    = [meshXmin,gridCOx];
   gridcheckX = gridcheckX+1;
 end
 if max(gridCOx)<meshXmax
   gridCOx    = [gridCOx,meshXmax];
   gridcheckX = gridcheckX+2;
 end
elseif ~isempty(strfind(raydirection,'y'))  &&  (min(gridCOy)>meshYmin || max(gridCOy)<meshYmax)
 gridcheckY = 0;
 if min(gridCOy)>meshYmin
   gridCOy    = [meshYmin,gridCOy];
   gridcheckY = gridcheckY+1;
 end
 if max(gridCOy)<meshYmax
   gridCOy    = [gridCOy,meshYmax];
   gridcheckY = gridcheckY+2;
 end
elseif ~isempty(strfind(raydirection,'z'))  &&  (min(gridCOz)>meshZmin || max(gridCOz)<meshZmax)
 gridcheckZ = 0;
 if min(gridCOz)>meshZmin
   gridCOz    = [meshZmin,gridCOz];
   gridcheckZ = gridcheckZ+1;
 end
 if max(gridCOz)<meshZmax
   gridCOz    = [gridCOz,meshZmax];
   gridcheckZ = gridcheckZ+2;
 end
end
%======================================================
% VOXELISE USING THE USER DEFINED RAY DIRECTION(S)
%======================================================
%Count the number of voxels in each direction:
voxcountX = numel(gridCOx);
voxcountY = numel(gridCOy);
voxcountZ = numel(gridCOz);
% Prepare logical array to hold the voxelised data:
gridOUTPUT      = false( voxcountX,voxcountY,voxcountZ,numel(raydirection) );
countdirections = 0;
if strfind(raydirection,'x')
 countdirections = countdirections + 1;
 gridOUTPUT(:,:,:,countdirections) = permute( VOXELISEinternal(gridCOy,gridCOz,gridCOx,meshXYZ(:,[2,3,1],:)) ,[3,1,2] );
end
if strfind(raydirection,'y')
 countdirections = countdirections + 1;
 gridOUTPUT(:,:,:,countdirections) = permute( VOXELISEinternal(gridCOz,gridCOx,gridCOy,meshXYZ(:,[3,1,2],:)) ,[2,3,1] );
end
if strfind(raydirection,'z')
 countdirections = countdirections + 1;
 gridOUTPUT(:,:,:,countdirections) = VOXELISEinternal(gridCOx,gridCOy,gridCOz,meshXYZ);
end
% Combine the results of each ray-tracing direction:
if numel(raydirection)>1
 gridOUTPUT = sum(gridOUTPUT,4)>=numel(raydirection)/2;
end
%======================================================
% RETURN THE OUTPUT GRID TO THE SIZE REQUIRED BY THE USER (IF IT WAS CHANGED EARLIER)
%======================================================
if exist('gridcheckX','var')
 if gridcheckX == 1
   gridOUTPUT = gridOUTPUT(2:end,:,:);
   gridCOx    = gridCOx(2:end);
 elseif gridcheckX == 2
   gridOUTPUT = gridOUTPUT(1:end-1,:,:);
   gridCOx    = gridCOx(1:end-1);
 elseif gridcheckX == 3
   gridOUTPUT = gridOUTPUT(2:end-1,:,:);
   gridCOx    = gridCOx(2:end-1);
 end
end
if exist('gridcheckY','var')
 if gridcheckY == 1
   gridOUTPUT = gridOUTPUT(:,2:end,:);
   gridCOy    = gridCOy(2:end);
 elseif gridcheckY == 2
   gridOUTPUT = gridOUTPUT(:,1:end-1,:);
   gridCOy    = gridCOy(1:end-1);
 elseif gridcheckY == 3
   gridOUTPUT = gridOUTPUT(:,2:end-1,:);
   gridCOy    = gridCOy(2:end-1);
 end
end
if exist('gridcheckZ','var')
 if gridcheckZ == 1
   gridOUTPUT = gridOUTPUT(:,:,2:end);
   gridCOz    = gridCOz(2:end);
 elseif gridcheckZ == 2
   gridOUTPUT = gridOUTPUT(:,:,1:end-1);
   gridCOz    = gridCOz(1:end-1);
 elseif gridcheckZ == 3
   gridOUTPUT = gridOUTPUT(:,:,2:end-1);
   gridCOz    = gridCOz(2:end-1);
 end
end
%======================================================
% PREPARE THE OUTPUT PARAMETERS
%======================================================
if nargout==4
 varargout(1) = {gridCOx};
 varargout(2) = {gridCOy};
 varargout(3) = {gridCOz};
end
end %function
%==========================================================================
%==========================================================================
function [gridOUTPUT] = VOXELISEinternal(gridCOx,gridCOy,gridCOz,meshXYZ)
%Count the number of voxels in each direction:
voxcountX = numel(gridCOx);
voxcountY = numel(gridCOy);
voxcountZ = numel(gridCOz);
% Prepare logical array to hold the voxelised data:
gridOUTPUT = false(voxcountX,voxcountY,voxcountZ);
%Identify the min and max x,y coordinates (cm) of the mesh:
meshXmin = min(min(meshXYZ(:,1,:)));
meshXmax = max(max(meshXYZ(:,1,:)));
meshYmin = min(min(meshXYZ(:,2,:)));
meshYmax = max(max(meshXYZ(:,2,:)));
meshZmin = min(min(meshXYZ(:,3,:)));
meshZmax = max(max(meshXYZ(:,3,:)));
%Identify the min and max x,y coordinates (pixels) of the mesh:
meshXminp = find(abs(gridCOx-meshXmin)==min(abs(gridCOx-meshXmin)));
meshXmaxp = find(abs(gridCOx-meshXmax)==min(abs(gridCOx-meshXmax)));
meshYminp = find(abs(gridCOy-meshYmin)==min(abs(gridCOy-meshYmin)));
meshYmaxp = find(abs(gridCOy-meshYmax)==min(abs(gridCOy-meshYmax)));
%Make sure min < max for the mesh coordinates:
if meshXminp > meshXmaxp
 [meshXminp,meshXmaxp] = deal(meshXmaxp,meshXminp);
end %if
if meshYminp > meshYmaxp
 [meshYminp,meshYmaxp] = deal(meshYmaxp,meshYminp);
end %if
%Identify the min and max x,y,z coordinates of each facet:
meshXYZmin = min(meshXYZ,[],3);
meshXYZmax = max(meshXYZ,[],3);
%======================================================
% VOXELISE THE MESH
%======================================================
correctionLIST = [];   %Prepare to record all rays that fail the voxelisation.  This array is built on-the-fly, but since
                      %it ought to be relatively small should not incur too much of a speed penalty.
                     
% Loop through each x,y pixel.
% The mesh will be voxelised by passing rays in the z-direction through
% each x,y pixel, and finding the locations where the rays cross the mesh.
for loopY = meshYminp:meshYmaxp
  % - 1a - Find which mesh facets could possibly be crossed by the ray:
 possibleCROSSLISTy = find( meshXYZmin(:,2)<=gridCOy(loopY) & meshXYZmax(:,2)>=gridCOy(loopY) );
  for loopX = meshXminp:meshXmaxp
  
   % - 1b - Find which mesh facets could possibly be crossed by the ray:
   possibleCROSSLIST = possibleCROSSLISTy( meshXYZmin(possibleCROSSLISTy,1)<=gridCOx(loopX) & meshXYZmax(possibleCROSSLISTy,1)>=gridCOx(loopX) );
   if isempty(possibleCROSSLIST)==0  %Only continue the analysis if some nearby facets were actually identified
        
     % - 2 - For each facet, check if the ray really does cross the facet rather than just passing it close-by:
        
     % GENERAL METHOD:
     % A. Take each edge of the facet in turn.
     % B. Find the position of the opposing vertex to that edge.
     % C. Find the position of the ray relative to that edge.
     % D. Check if ray is on the same side of the edge as the opposing vertex.
     % E. If this is true for all three edges, then the ray definitely passes through the facet.
     %
     % NOTES:
     % A. If a ray crosses exactly on a vertex:
     %    a. If the surrounding facets have normal components pointing in the same (or opposite) direction as the ray then the face IS crossed.
     %    b. Otherwise, add the ray to the correctionlist.
    
     facetCROSSLIST = [];   %Prepare to record all facets which are crossed by the ray.  This array is built on-the-fly, but since
                            %it ought to be relatively small (typically a list of <10) should not incur too much of a speed penalty.
    
     %----------
     % - 1 - Check for crossed vertices:
     %----------
    
     % Find which mesh facets contain a vertex which is crossed by the ray:
     vertexCROSSLIST = possibleCROSSLIST( (meshXYZ(possibleCROSSLIST,1,1)==gridCOx(loopX) & meshXYZ(possibleCROSSLIST,2,1)==gridCOy(loopY)) ...
                                        | (meshXYZ(possibleCROSSLIST,1,2)==gridCOx(loopX) & meshXYZ(possibleCROSSLIST,2,2)==gridCOy(loopY)) ...
                                        | (meshXYZ(possibleCROSSLIST,1,3)==gridCOx(loopX) & meshXYZ(possibleCROSSLIST,2,3)==gridCOy(loopY)) ...
                                        );
    
     if isempty(vertexCROSSLIST)==0  %Only continue the analysis if potential vertices were actually identified
       checkindex = zeros(1,numel(vertexCROSSLIST));
       while min(checkindex) == 0
        
         vertexindex             = find(checkindex==0,1,'first');
         checkindex(vertexindex) = 1;
      
         [temp.faces,temp.vertices] = CONVERT_meshformat(meshXYZ(vertexCROSSLIST,:,:));
         adjacentindex              = ismember(temp.faces,temp.faces(vertexindex,:));
         adjacentindex              = max(adjacentindex,[],2);
         checkindex(adjacentindex)  = 1;
      
         coN = COMPUTE_mesh_normals(meshXYZ(vertexCROSSLIST(adjacentindex),:,:));
      
         if max(coN(:,3))<0 || min(coN(:,3))>0
           facetCROSSLIST    = [facetCROSSLIST,vertexCROSSLIST(vertexindex)];
         else
           possibleCROSSLIST = [];
           correctionLIST    = [ correctionLIST; loopX,loopY ];
           checkindex(:)     = 1;
         end
      
       end
      
     end
    
     %----------
     % - 2 - Check for crossed facets:
     %----------
    
     if isempty(possibleCROSSLIST)==0  %Only continue the analysis if some nearby facets were actually identified
        
       for loopCHECKFACET = possibleCROSSLIST'
          %Check if ray crosses the facet.  This method is much (>>10 times) faster than using the built-in function 'inpolygon'.
         %Taking each edge of the facet in turn, check if the ray is on the same side as the opposing vertex.
      
         Y1predicted = meshXYZ(loopCHECKFACET,2,2) - ((meshXYZ(loopCHECKFACET,2,2)-meshXYZ(loopCHECKFACET,2,3)) * (meshXYZ(loopCHECKFACET,1,2)-meshXYZ(loopCHECKFACET,1,1))/(meshXYZ(loopCHECKFACET,1,2)-meshXYZ(loopCHECKFACET,1,3)));
         YRpredicted = meshXYZ(loopCHECKFACET,2,2) - ((meshXYZ(loopCHECKFACET,2,2)-meshXYZ(loopCHECKFACET,2,3)) * (meshXYZ(loopCHECKFACET,1,2)-gridCOx(loopX))/(meshXYZ(loopCHECKFACET,1,2)-meshXYZ(loopCHECKFACET,1,3)));
      
         if (Y1predicted > meshXYZ(loopCHECKFACET,2,1) && YRpredicted > gridCOy(loopY)) || (Y1predicted < meshXYZ(loopCHECKFACET,2,1) && YRpredicted < gridCOy(loopY))
           %The ray is on the same side of the 2-3 edge as the 1st vertex.
           Y2predicted = meshXYZ(loopCHECKFACET,2,3) - ((meshXYZ(loopCHECKFACET,2,3)-meshXYZ(loopCHECKFACET,2,1)) * (meshXYZ(loopCHECKFACET,1,3)-meshXYZ(loopCHECKFACET,1,2))/(meshXYZ(loopCHECKFACET,1,3)-meshXYZ(loopCHECKFACET,1,1)));
           YRpredicted = meshXYZ(loopCHECKFACET,2,3) - ((meshXYZ(loopCHECKFACET,2,3)-meshXYZ(loopCHECKFACET,2,1)) * (meshXYZ(loopCHECKFACET,1,3)-gridCOx(loopX))/(meshXYZ(loopCHECKFACET,1,3)-meshXYZ(loopCHECKFACET,1,1)));
        
           if (Y2predicted > meshXYZ(loopCHECKFACET,2,2) && YRpredicted > gridCOy(loopY)) || (Y2predicted < meshXYZ(loopCHECKFACET,2,2) && YRpredicted < gridCOy(loopY))
             %The ray is on the same side of the 3-1 edge as the 2nd vertex.
             Y3predicted = meshXYZ(loopCHECKFACET,2,1) - ((meshXYZ(loopCHECKFACET,2,1)-meshXYZ(loopCHECKFACET,2,2)) * (meshXYZ(loopCHECKFACET,1,1)-meshXYZ(loopCHECKFACET,1,3))/(meshXYZ(loopCHECKFACET,1,1)-meshXYZ(loopCHECKFACET,1,2)));
             YRpredicted = meshXYZ(loopCHECKFACET,2,1) - ((meshXYZ(loopCHECKFACET,2,1)-meshXYZ(loopCHECKFACET,2,2)) * (meshXYZ(loopCHECKFACET,1,1)-gridCOx(loopX))/(meshXYZ(loopCHECKFACET,1,1)-meshXYZ(loopCHECKFACET,1,2)));
          
             if (Y3predicted > meshXYZ(loopCHECKFACET,2,3) && YRpredicted > gridCOy(loopY)) || (Y3predicted < meshXYZ(loopCHECKFACET,2,3) && YRpredicted < gridCOy(loopY))
               %The ray is on the same side of the 1-2 edge as the 3rd vertex.
               %The ray passes through the facet since it is on the correct side of all 3 edges
               facetCROSSLIST = [facetCROSSLIST,loopCHECKFACET];
          
             end %if
           end %if
         end %if
    
       end %for
  
       %----------
       % - 3 - Find the z coordinate of the locations where the ray crosses each facet or vertex:
       %----------
       gridCOzCROSS = zeros(size(facetCROSSLIST));
       for loopFINDZ = facetCROSSLIST
         % METHOD:
         % 1. Define the equation describing the plane of the facet.  For a
         % more detailed outline of the maths, see:
         % http://local.wasp.uwa.edu.au/~pbourke/geometry/planeeq/
         %    Ax + By + Cz + D = 0
         %    where  A = y1 (z2 - z3) + y2 (z3 - z1) + y3 (z1 - z2)
         %           B = z1 (x2 - x3) + z2 (x3 - x1) + z3 (x1 - x2)
         %           C = x1 (y2 - y3) + x2 (y3 - y1) + x3 (y1 - y2)
         %           D = - x1 (y2 z3 - y3 z2) - x2 (y3 z1 - y1 z3) - x3 (y1 z2 - y2 z1)
         % 2. For the x and y coordinates of the ray, solve these equations to find the z coordinate in this plane.
         planecoA = meshXYZ(loopFINDZ,2,1)*(meshXYZ(loopFINDZ,3,2)-meshXYZ(loopFINDZ,3,3)) + meshXYZ(loopFINDZ,2,2)*(meshXYZ(loopFINDZ,3,3)-meshXYZ(loopFINDZ,3,1)) + meshXYZ(loopFINDZ,2,3)*(meshXYZ(loopFINDZ,3,1)-meshXYZ(loopFINDZ,3,2));
         planecoB = meshXYZ(loopFINDZ,3,1)*(meshXYZ(loopFINDZ,1,2)-meshXYZ(loopFINDZ,1,3)) + meshXYZ(loopFINDZ,3,2)*(meshXYZ(loopFINDZ,1,3)-meshXYZ(loopFINDZ,1,1)) + meshXYZ(loopFINDZ,3,3)*(meshXYZ(loopFINDZ,1,1)-meshXYZ(loopFINDZ,1,2));
         planecoC = meshXYZ(loopFINDZ,1,1)*(meshXYZ(loopFINDZ,2,2)-meshXYZ(loopFINDZ,2,3)) + meshXYZ(loopFINDZ,1,2)*(meshXYZ(loopFINDZ,2,3)-meshXYZ(loopFINDZ,2,1)) + meshXYZ(loopFINDZ,1,3)*(meshXYZ(loopFINDZ,2,1)-meshXYZ(loopFINDZ,2,2));
         planecoD = - meshXYZ(loopFINDZ,1,1)*(meshXYZ(loopFINDZ,2,2)*meshXYZ(loopFINDZ,3,3)-meshXYZ(loopFINDZ,2,3)*meshXYZ(loopFINDZ,3,2)) - meshXYZ(loopFINDZ,1,2)*(meshXYZ(loopFINDZ,2,3)*meshXYZ(loopFINDZ,3,1)-meshXYZ(loopFINDZ,2,1)*meshXYZ(loopFINDZ,3,3)) - meshXYZ(loopFINDZ,1,3)*(meshXYZ(loopFINDZ,2,1)*meshXYZ(loopFINDZ,3,2)-meshXYZ(loopFINDZ,2,2)*meshXYZ(loopFINDZ,3,1));
         if abs(planecoC) < 1e-14
           planecoC=0;
         end
    
         gridCOzCROSS(facetCROSSLIST==loopFINDZ) = (- planecoD - planecoA*gridCOx(loopX) - planecoB*gridCOy(loopY)) / planecoC;
      
       end %for
       %Remove values of gridCOzCROSS which are outside of the mesh limits (including a 1e-12 margin for error).
       gridCOzCROSS = gridCOzCROSS( gridCOzCROSS>=meshZmin-1e-12 & gridCOzCROSS<=meshZmax+1e-12 );
    
       %Round gridCOzCROSS to remove any rounding errors, and take only the unique values:
       gridCOzCROSS = round(gridCOzCROSS*1e12)/1e12;
       gridCOzCROSS = unique(gridCOzCROSS);
    
       %----------
       % - 4 - Label as being inside the mesh all the voxels that the ray passes through after crossing one facet before crossing another facet:
       %----------
       if rem(numel(gridCOzCROSS),2)==0  % Only rays which cross an even number of facets are voxelised
         for loopASSIGN = 1:(numel(gridCOzCROSS)/2)
           voxelsINSIDE = (gridCOz>gridCOzCROSS(2*loopASSIGN-1) & gridCOz<gridCOzCROSS(2*loopASSIGN));
           gridOUTPUT(loopX,loopY,voxelsINSIDE) = 1;
         end %for
      
       elseif numel(gridCOzCROSS)~=0    % Remaining rays which meet the mesh in some way are not voxelised, but are labelled for correction later.
        
         correctionLIST = [ correctionLIST; loopX,loopY ];
      
       end %if
     end
    
   end %if
 end %for
end %for
%======================================================
% USE INTERPOLATION TO FILL IN THE RAYS WHICH COULD NOT BE VOXELISED
%======================================================
%For rays where the voxelisation did not give a clear result, the ray is
%computed by interpolating from the surrounding rays.
countCORRECTIONLIST = size(correctionLIST,1);
if countCORRECTIONLIST>0
  
 %If necessary, add a one-pixel border around the x and y edges of the
 %array.  This prevents an error if the code tries to interpolate a ray at
 %the edge of the x,y grid.
 if min(correctionLIST(:,1))==1 || max(correctionLIST(:,1))==numel(gridCOx) || min(correctionLIST(:,2))==1 || max(correctionLIST(:,2))==numel(gridCOy)
   gridOUTPUT     = [zeros(1,voxcountY+2,voxcountZ);zeros(voxcountX,1,voxcountZ),gridOUTPUT,zeros(voxcountX,1,voxcountZ);zeros(1,voxcountY+2,voxcountZ)];
   correctionLIST = correctionLIST + 1;
 end
  for loopC = 1:countCORRECTIONLIST
   voxelsforcorrection = squeeze( sum( [ gridOUTPUT(correctionLIST(loopC,1)-1,correctionLIST(loopC,2)-1,:) ,...
                                         gridOUTPUT(correctionLIST(loopC,1)-1,correctionLIST(loopC,2),:)   ,...
                                         gridOUTPUT(correctionLIST(loopC,1)-1,correctionLIST(loopC,2)+1,:) ,...
                                         gridOUTPUT(correctionLIST(loopC,1),correctionLIST(loopC,2)-1,:)   ,...
                                         gridOUTPUT(correctionLIST(loopC,1),correctionLIST(loopC,2)+1,:)   ,...
                                         gridOUTPUT(correctionLIST(loopC,1)+1,correctionLIST(loopC,2)-1,:) ,...
                                         gridOUTPUT(correctionLIST(loopC,1)+1,correctionLIST(loopC,2),:)   ,...
                                         gridOUTPUT(correctionLIST(loopC,1)+1,correctionLIST(loopC,2)+1,:) ,...
                                        ] ) );
   voxelsforcorrection = (voxelsforcorrection>=4);
   gridOUTPUT(correctionLIST(loopC,1),correctionLIST(loopC,2),voxelsforcorrection) = 1;
 end %for
 %Remove the one-pixel border surrounding the array, if this was added
 %previously.
 if size(gridOUTPUT,1)>numel(gridCOx) || size(gridOUTPUT,2)>numel(gridCOy)
   gridOUTPUT = gridOUTPUT(2:end-1,2:end-1,:);
 end
 end %if
%disp([' Ray tracing result: ',num2str(countCORRECTIONLIST),' rays (',num2str(countCORRECTIONLIST/(voxcountX*voxcountY)*100,'%5.1f'),'% of all rays) exactly crossed a facet edge and had to be computed by interpolation.'])
end %function
%==========================================================================

%Plotting Voxels
    
