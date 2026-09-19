let isLoginMode = true;

document.getElementById('toggleAuthMode').addEventListener('click', (e) => {
    e.preventDefault();
    isLoginMode = !isLoginMode;
    document.getElementById('authSubmitBtn').textContent = isLoginMode ? 'Login' : 'Sign Up';
    e.target.textContent = isLoginMode ? 'Need an account? Sign up' : 'Already have an account? Login';
    document.getElementById('authSubtitle').textContent = isLoginMode ? 'Sign in to manage your life' : 'Create an account to start planning';
});

document.getElementById('authForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const email = document.getElementById('authEmail').value;
    const pass = document.getElementById('authPassword').value;
    
    // Set UI to loading state
    const authBtn = document.getElementById('authSubmitBtn');
    if(authBtn) {
        authBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span> Please wait...';
        authBtn.disabled = true;
    }

    if (isLoginMode) {
        auth.signInWithEmailAndPassword(email, pass).catch(err => {
            alert("Login Error: " + err.message);
            resetAuthBtn();
        });
    } else {
        auth.createUserWithEmailAndPassword(email, pass).catch(err => {
            alert("Signup Error: " + err.message);
            resetAuthBtn();
        });
    }
});

function resetAuthBtn() {
    const authBtn = document.getElementById('authSubmitBtn');
    if(authBtn) {
        authBtn.innerHTML = isLoginMode ? 'Login' : 'Sign Up';
        authBtn.disabled = false;
    }
}

document.getElementById('googleSignInBtn').addEventListener('click', () => {
    auth.signInWithPopup(googleProvider).catch(err => alert("Google Auth Error: " + err.message));
});

document.getElementById('logoutBtn').addEventListener('click', () => auth.signOut());

// Listen to Auth State
auth.onAuthStateChanged(user => {
    if (user) {
        currentUserUid = user.uid;
        currentWorkspaceUid = user.uid; 
        currentWorkspaceRole = 'owner';

        // Save email lookup so users can be found for sharing
        const escapedEmail = user.email.toLowerCase().replace(/\./g, ',');
        database.ref(`emailToUid/${escapedEmail}`).set({ 
            uid: user.uid, 
            name: user.displayName || user.email 
        });

        profileRef = database.ref(`users/${user.uid}/profile`);
        
        profileRef.once('value', snapshot => {
            if (!snapshot.exists()) {
                document.getElementById('auth-section').classList.add('d-none');
                document.getElementById('profile-setup-section').classList.remove('d-none');
                resetAuthBtn(); 
            } else {
                loadDashboard(snapshot.val().name);
                resetAuthBtn(); 
            }
        });
    } else {
        currentUserUid = null;
        if(tripsRef) tripsRef.off();
        if(todosRef) todosRef.off();
        document.getElementById('auth-section').classList.remove('d-none');
        document.getElementById('app-section').classList.add('d-none');
        document.getElementById('profile-setup-section').classList.add('d-none');
        document.getElementById('authForm').reset();
        resetAuthBtn();
    }
});

function loadDashboard(name) {
    document.getElementById('auth-section').classList.add('d-none');
    document.getElementById('profile-setup-section').classList.add('d-none');
    document.getElementById('app-section').classList.remove('d-none');
    document.getElementById('userNameDisplay').textContent = `Hi, ${name}`;
    
    // Load Workspaces Shared with Me
    listenToSharedWorkspaces();
    
    // Load My Collaborators settings
    loadCollaborators();

    // Default connection to your own workspace
    switchWorkspace(currentUserUid, 'owner', 'My Workspace');
}

function listenToSharedWorkspaces() {
    database.ref(`users/${currentUserUid}/sharedWithMe`).on('value', snap => {
        const list = document.getElementById('workspaceList');
        const isMyWorkspace = currentWorkspaceUid === currentUserUid;
        
        // Base Option
        list.innerHTML = `<li><a class="dropdown-item ${isMyWorkspace ? 'active' : ''}" href="#" onclick="switchWorkspace('${currentUserUid}', 'owner', 'My Workspace')">My Workspace</a></li>`;
        
        let foundCurrentWorkspace = false;

        if(snap.exists()) {
            snap.forEach(child => {
                const ownerUid = child.key;
                const role = child.val().role;
                const ownerName = child.val().ownerName || 'Shared User';
                
                // Construct safe strings for JS formatting
                const safeName = ownerName.replace(/'/g, "\\'");
                const displayName = `${ownerName}'s Workspace (${role})`;
                const isActive = currentWorkspaceUid === ownerUid ? 'active' : '';

                // Add to list
                list.innerHTML += `<li><a class="dropdown-item ${isActive}" href="#" onclick="switchWorkspace('${ownerUid}', '${role}', '${safeName}\\'s Workspace (${role})')">${displayName}</a></li>`;
                
                // LIVE UPDATE: If the user is CURRENTLY looking at this workspace and the owner just changed their role
                if (currentWorkspaceUid === ownerUid) {
                    foundCurrentWorkspace = true;
                    currentWorkspaceRole = role; // update session role instantly
                    document.getElementById('workspaceDropdown').textContent = displayName;

                    // Re-trigger Add Forms visibility
                    const canAdd = role === 'owner' || role === 'master' || role === 'add';
                    const tripSection = document.getElementById('tripFormSection');
                    const todoSection = document.getElementById('todoFormSection');
                    if(tripSection) tripSection.style.display = canAdd ? 'block' : 'none';
                    if(todoSection) todoSection.style.display = canAdd ? 'block' : 'none';
                    
                    // Force redraw of Trips & Todos to add/remove Edit & Delete buttons based on new role
                    initTripsListener();
                    initTodosListener();
                }
            });
        }

        // If we are viewing our own workspace
        if (currentWorkspaceUid === currentUserUid) {
            document.getElementById('workspaceDropdown').textContent = 'My Workspace';
        } else if (!foundCurrentWorkspace && currentWorkspaceUid !== currentUserUid) {
            // If we were viewing a workspace but our access was completely revoked, kick back to home
            alert("Your access to the active workspace was modified or revoked.");
            switchWorkspace(currentUserUid, 'owner', 'My Workspace');
        }
    });
}