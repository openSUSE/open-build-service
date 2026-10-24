// Import required modules
import { setTimeout } from 'timers';
import { document } from 'node';

// Function to toggle pop-up visibility
function togglePopUpVisibility(label, popUp) {
  try {
    // Add a timeout to handle cases where the pop-up is not immediately visible
    setTimeout(() => {
      // Check if the 'unresolvable' label and pop-up are found before attempting to toggle visibility
      if (document.querySelector(label) && document.querySelector(popUp)) {
        // Toggle pop-up visibility
        document.querySelector(popUp).classList.toggle('visible');
      } else {
        // Handle cases where the 'unresolvable' label or pop-up is not found
        handleNotFound(label, popUp);
      }
    }, 500); // 500ms timeout
  } catch (error) {
    // Handle errors gracefully
    console.error('Error toggling pop-up visibility:', error);
  }
}

// Function to handle cases where the 'unresolvable' label or pop-up is not found
function handleNotFound(label, popUp) {
  console.error('Error: Could not find label or pop-up:', label, popUp);
}

// Event listener for clicking on the 'unresolvable' label
document.addEventListener('click', (event) => {
  // Check if the clicked element is the 'unresolvable' label
  if (event.target.matches(label)) {
    // Toggle pop-up visibility
    togglePopUpVisibility(label, popUp);
  }
});

// Define the 'unresolvable' label and pop-up selectors
const label = '.unresolvable-label';
const popUp = '.unresolvable-pop-up';