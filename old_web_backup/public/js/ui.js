// Tab Switching logic
document.querySelectorAll('.nav-tab').forEach(tab => {
    tab.addEventListener('click', (e) => {
        e.preventDefault();
        document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.view-section').forEach(v => v.classList.add('d-none'));
        
        e.target.classList.add('active');
        document.getElementById(e.target.dataset.target).classList.remove('d-none');
    });
});

document.getElementById('year').textContent = new Date().getFullYear();

function formatDisplayDate(isoDate) {
    if (!isoDate) return "—";
    const dateObj = new Date(isoDate);
    if (isNaN(dateObj.getTime())) return "Invalid Date";
    const day = String(dateObj.getDate()).padStart(2, '0');
    const month = String(dateObj.getMonth() + 1).padStart(2, '0');
    const dayName = dateObj.toLocaleString('en-US', { weekday: 'short' });
    return `${day}-${month}-${dateObj.getFullYear()}, ${dayName}`;
}

function getRelativeStatus(isoDate) {
    if (!isoDate) return "—";
    const target = new Date(isoDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const diffTime = target - today;
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays < 0) return "Past";
    if (diffDays === 0) return "Today";
    if (diffDays === 1) return "Tomorrow";
    return `In ${diffDays} days`;
}

// Custom Confirmation Modal Logic
const confirmActionModal = new bootstrap.Modal(document.getElementById('confirmActionModal'));
let currentConfirmCallback = null;

window.showConfirmModal = (title, message, confirmText, callback) => {
    document.getElementById('confirmActionTitle').textContent = title;
    document.getElementById('confirmActionMessage').textContent = message;
    document.getElementById('confirmActionBtn').textContent = confirmText;
    currentConfirmCallback = callback;
    confirmActionModal.show();
};

document.getElementById('confirmActionBtn').addEventListener('click', () => {
    if (currentConfirmCallback) currentConfirmCallback();
    confirmActionModal.hide();
});

window.confirmDelete = (refPath) => {
    showConfirmModal(
        "Delete Permanently",
        "Are you sure you want to delete this permanently? This action cannot be undone.",
        "Yes, Delete",
        () => { database.ref(refPath).remove(); }
    );
};

// ==========================================
// Workspace Sharing & Collaboration Logic
// ==========================================

window.switchWorkspace = (uid, role, name) => {
    currentWorkspaceUid = uid;
    currentWorkspaceRole = role;
    
    // Update the visual name on the navbar
    document.getElementById('workspaceDropdown').textContent = name;
    
    // Stop listening to previous workspace data
    if(tripsRef) tripsRef.off();
    if(todosRef) todosRef.off();
    
    // Bind to the newly selected workspace
    tripsRef = database.ref(`users/${currentWorkspaceUid}/trips`);
    todosRef = database.ref(`users/${currentWorkspaceUid}/todos`);
    
    initTripsListener();
    initTodosListener();

    // Permissions System UI Toggles
    const canAdd = role === 'owner' || role === 'master' || role === 'add';
    const tripSection = document.getElementById('tripFormSection');
    const todoSection = document.getElementById('todoFormSection');
    if(tripSection) tripSection.style.display = canAdd ? 'block' : 'none';
    if(todoSection) todoSection.style.display = canAdd ? 'block' : 'none';

    // Update the active state visually in the dropdown
    document.querySelectorAll('#workspaceList .dropdown-item').forEach(item => {
        item.classList.remove('active');
        if (item.textContent === name) {
            item.classList.add('active');
        }
    });
};

// Submit Share Form (With Loading Indicator)
document.getElementById('shareForm').addEventListener('submit', (e) => {
    e.preventDefault();
    
    // Set UI to loading state
    const shareBtn = document.getElementById('shareSubmitBtn');
    const originalText = shareBtn.innerHTML;
    shareBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span> Sharing...';
    shareBtn.disabled = true;

    const originalEmail = document.getElementById('shareEmail').value;
    const email = originalEmail.toLowerCase().replace(/\./g, ',');
    const role = document.getElementById('shareRole').value;
    
    if (originalEmail.toLowerCase() === auth.currentUser.email.toLowerCase()) {
        alert("You cannot share the workspace with yourself.");
        resetShareBtn(shareBtn, originalText);
        return;
    }

    database.ref(`emailToUid/${email}`).once('value', snap => {
        if(!snap.exists()) {
            alert("User not found! They must create an account first.");
            resetShareBtn(shareBtn, originalText);
            return;
        }
        const targetUid = snap.val().uid;
        
        // Save rule in your collaborators list
        database.ref(`users/${currentUserUid}/collaborators/${targetUid}`).set({ 
            email: originalEmail, 
            role: role 
        });
        
        // Add invite into their SharedWithMe dashboard
        database.ref(`users/${currentUserUid}/profile`).once('value', profileSnap => {
            const myName = profileSnap.val() ? profileSnap.val().name : 'Someone';
            database.ref(`users/${targetUid}/sharedWithMe/${currentUserUid}`).set({ 
                role: role, 
                ownerName: myName 
            }).then(() => {
                // Clear form and reset button on success
                document.getElementById('shareForm').reset();
                resetShareBtn(shareBtn, originalText);
            }).catch(err => {
                alert("Error sharing: " + err.message);
                resetShareBtn(shareBtn, originalText);
            });
        });
    }).catch(err => {
        alert("Database Error: " + err.message);
        resetShareBtn(shareBtn, originalText);
    });
});

// Helper to reset share button
function resetShareBtn(btnElement, originalHtml) {
    btnElement.innerHTML = originalHtml;
    btnElement.disabled = false;
}

// Render Collaborators List (Now with inline Role Editing)
window.loadCollaborators = () => {
    database.ref(`users/${currentUserUid}/collaborators`).on('value', snap => {
        const list = document.getElementById('sharedWithList');
        list.innerHTML = '';
        if(snap.exists()){
            snap.forEach(child => {
                const data = child.val();
                
                // Construct list item with dynamic dropdown for live role editing
                list.innerHTML += `
                <li class="list-group-item d-flex justify-content-between align-items-center flex-wrap gap-2 py-3">
                    <div><strong class="text-dark m-0">${data.email}</strong></div>
                    <div class="d-flex align-items-center gap-2">
                        <select class="form-select form-select-sm rounded-pill shadow-sm" style="width: 120px;" onchange="updateCollaboratorRole('${child.key}', this.value)">
                            <option value="view" ${data.role === 'view' ? 'selected' : ''}>View Only</option>
                            <option value="add" ${data.role === 'add' ? 'selected' : ''}>Add Only</option>
                            <option value="master" ${data.role === 'master' ? 'selected' : ''}>Master</option>
                        </select>
                        <button class="btn btn-sm btn-outline-danger rounded-pill fw-bold" onclick="removeCollaborator('${child.key}')"><i class="bi bi-trash"></i> Revoke</button>
                    </div>
                </li>`;
            });
        } else {
            list.innerHTML = '<li class="list-group-item text-muted text-center py-4">Not shared with anyone yet</li>';
        }
    });
};

// Function to handle live role updates
window.updateCollaboratorRole = (targetUid, newRole) => {
    // 1. Update your own collaborators directory
    database.ref(`users/${currentUserUid}/collaborators/${targetUid}`).update({ role: newRole });
    
    // 2. Update the target user's "sharedWithMe" directory so their permissions take effect
    database.ref(`users/${targetUid}/sharedWithMe/${currentUserUid}`).update({ role: newRole })
        .catch(err => alert("Error updating role: " + err.message));
};

// Function to kick a user entirely
window.removeCollaborator = (targetUid) => {
    if(confirm("Are you sure you want to revoke access for this user?")) {
        database.ref(`users/${currentUserUid}/collaborators/${targetUid}`).remove();
        database.ref(`users/${targetUid}/sharedWithMe/${currentUserUid}`).remove();
    }
};