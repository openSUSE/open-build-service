// Import required modules
import { document } from 'node';

// Function to handle cases where the 'unresolvable' label or pop-up is not found
function handleNotFound(label, popUp) {
  console.error('Error: Could not find label or pop-up:', label, popUp);
}

// Export the handleNotFound function
export { handleNotFound };