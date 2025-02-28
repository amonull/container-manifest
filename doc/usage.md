# Usage

manifest.sh is simple to use just make sure a valid yaml file is supplied (check [manifest-structure](./manifest-structure.md) for examples).

# Options
|           Args           	|                Input               	|                          Desc                         	|             Example            	| Required 	|
|:------------------------:	|:----------------------------------:	|:-----------------------------------------------------:	|:------------------------------:	|:--------:	|
|      -m, --manifest      	| path to a valid manifest yaml file 	|   uses the given input to start creating a container  	| `manifest.sh -m /path/to/file` 	|   True   	|
|    -B, --ignore-build    	|                 N/A                	| Does not build the image defined in the manifest file 	|        `manifest.sh -B`        	|   False  	|
| -F, --ignore-build-files 	|                 N/A                	|     Does not create files declared in image::files    	|        `manifest.sh -F`        	|   False  	|
|  -D, --ignore-container  	|                 N/A                	|              Does not create a container              	|        `manifest.sh -D`        	|   False  	|
|     -P, --ignore-pre     	|                 N/A                	|      Does not run pre commands (or creates them)      	|        `manifest.sh -P`        	|   False  	|
|     -R, -ignore-peri     	|                 N/A                	|      Does not run peri commands (or creates them)     	|        `manifest.sh -R`        	|   False  	|
|     -T, --ignore-post    	|                 N/A                	|      Does not run post commands (or creates them)     	|        `manifest.sh -T`        	|   False  	|
|    -I, --ignore-import   	|                 N/A                	|              Does not import to container             	|        `manifest.sh -I`        	|   False  	|
|    -E, --ignore-export   	|                 N/A                	|             Does not export from container            	|        `manifest.sh -E`        	|   False  	|
|      -K, --keep-tmp      	|                 N/A                	|        Keeps the tmp files under /tmp/tmp.XXXXX       	|        `manifest.sh -K`        	|   False  	|