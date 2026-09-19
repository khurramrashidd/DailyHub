document.getElementById('profileForm').addEventListener('submit', (e) => {
    e.preventDefault();
    const name = document.getElementById('profileName').value;
    const phone = document.getElementById('profilePhone').value;

    profileRef.set({ name, phone, createdAt: new Date().toISOString() })
        .then(() => loadDashboard(name))
        .catch(err => alert("Error saving profile: " + err.message));
});