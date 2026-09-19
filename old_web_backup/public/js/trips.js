document.getElementById('transportType').addEventListener('change', (e) => {
    const type = e.target.value;
    const fields = document.getElementById('dynamicTripFields');
    let html = '';
    
    if (type === 'flight') {
        html = `
            <div class="row g-3 mt-1">
                <div class="col-md-12"><label class="form-label text-secondary fw-semibold">Airline</label><input type="text" id="tripAirline" class="form-control rounded-pill"></div>
                <div class="col-md-12"><label class="form-label text-secondary fw-semibold">PNR</label><input type="text" id="tripPnr" class="form-control rounded-pill"></div>
                <div class="col-md-12"><label class="form-label text-secondary fw-semibold">Booked From</label><input type="text" id="tripBookedFrom" class="form-control rounded-pill"></div>
            </div>`;
    } else if (type === 'train') {
        html = `
            <div class="row g-3 mt-1">
                <div class="col-md-12"><label class="form-label text-secondary fw-semibold">Train Name / Number</label><input type="text" id="tripTrain" class="form-control rounded-pill"></div>
                <div class="col-md-12"><label class="form-label text-secondary fw-semibold">PNR (IRCTC)</label><input type="text" id="tripPnr" class="form-control rounded-pill"></div>
                <div class="col-md-12"><label class="form-label text-secondary fw-semibold">Booked From</label><input type="text" id="tripBookedFrom" class="form-control rounded-pill"></div>
            </div>`;
    } else if (type === 'bus') {
        html = `
            <div class="row g-3 mt-1">
                <div class="col-md-12"><label class="form-label text-secondary fw-semibold">Bus Operator</label><input type="text" id="tripBus" class="form-control rounded-pill"></div>
                <div class="col-md-12"><label class="form-label text-secondary fw-semibold">Ticket Number</label><input type="text" id="tripTicket" class="form-control rounded-pill"></div>
                <div class="col-md-12"><label class="form-label text-secondary fw-semibold">Booked From</label><input type="text" id="tripBookedFrom" class="form-control rounded-pill"></div>
            </div>`;
    } else if (type === 'car') {
        html = `
            <div class="row g-3 mt-1">
                <div class="col-md-12"><label class="form-label text-secondary fw-semibold">Car Details (optional)</label><input type="text" id="tripCarDetails" class="form-control rounded-pill"></div>
            </div>`;
    }
    fields.innerHTML = html;
});

// Submit new trip
document.getElementById('tripForm').addEventListener('submit', (e) => {
    e.preventDefault();
    if (!tripsRef) return;
    if (currentWorkspaceRole === 'view') return alert('Permission denied.');
    
    let tripData = {
        type: document.getElementById('transportType').value,
        from: document.getElementById('tripFrom').value,
        to: document.getElementById('tripTo').value,
        depDate: document.getElementById('tripDepDate').value,
        arrDate: document.getElementById('tripArrDate').value,
        depTime: document.getElementById('tripDepTime').value,
        arrTime: document.getElementById('tripArrTime').value,
        status: 'upcoming'
    };

    if(document.getElementById('tripAirline')) tripData.airline = document.getElementById('tripAirline').value;
    if(document.getElementById('tripPnr')) tripData.pnr = document.getElementById('tripPnr').value;
    if(document.getElementById('tripTrain')) tripData.trainName = document.getElementById('tripTrain').value;
    if(document.getElementById('tripBus')) tripData.busOperator = document.getElementById('tripBus').value;
    if(document.getElementById('tripTicket')) tripData.ticketNo = document.getElementById('tripTicket').value;
    if(document.getElementById('tripBookedFrom')) tripData.bookedFrom = document.getElementById('tripBookedFrom').value;
    if(document.getElementById('tripCarDetails')) tripData.carDetails = document.getElementById('tripCarDetails').value;

    tripsRef.push().set(tripData)
        .then(() => {
            alert('Trip added successfully!');
            document.getElementById('tripForm').reset();
            document.getElementById('dynamicTripFields').innerHTML = '';
        });
});

function initTripsListener() {
    if (!tripsRef) return;

    tripsRef.on('value', snapshot => {
        const upcoming = document.getElementById('upcomingTrips');
        const completed = document.getElementById('completedTrips');
        const cancelled = document.getElementById('cancelledTrips');
        
        upcoming.innerHTML = ''; completed.innerHTML = ''; cancelled.innerHTML = '';
        
        let tripsArray = [];
        if (snapshot.exists()) {
            snapshot.forEach(child => {
                tripsArray.push({ id: child.key, ...child.val() });
            });
        }

        tripsArray.sort((a, b) => {
            const da = a.depDate || '9999-12-31';
            const db = b.depDate || '9999-12-31';
            return new Date(da) - new Date(db);
        });

        tripsArray.forEach(trip => {
            const relative = getRelativeStatus(trip.depDate);
            let badgeClass = "bg-secondary";
            
            if (relative === "Today") badgeClass = "bg-success";
            else if (relative === "Tomorrow") badgeClass = "bg-warning text-dark";
            else if (relative.startsWith("In ")) badgeClass = "bg-info text-dark";

            const relativeBadge = `<span class="badge ${badgeClass} ms-2">${relative}</span>`;
            
            // Generate Buttons Dynamically based on Status & Role
            let actionButtons = '';
            const canModify = currentWorkspaceRole === 'owner' || currentWorkspaceRole === 'master';

            if (canModify) {
                if (trip.status === 'upcoming') {
                    actionButtons = `
                        <button class="btn btn-complete-action flex-fill rounded-pill" onclick="updateTripStatus('${trip.id}', 'completed')"><i class="bi bi-check-circle"></i> Done</button>
                        <button class="btn btn-cancel-action flex-fill rounded-pill" onclick="confirmCancelTrip('${trip.id}')"><i class="bi bi-x-circle"></i> Cancel</button>
                        <button class="btn btn-reschedule-action flex-fill rounded-pill" onclick="openRescheduleModal('${trip.id}', '${trip.depDate}', '${trip.arrDate}', '${trip.depTime}', '${trip.arrTime}')"><i class="bi bi-arrow-repeat"></i> Reschedule</button>
                        <button class="btn btn-edit-action flex-fill rounded-pill" onclick="openEditModal('${trip.id}', '${trip.from}', '${trip.to}', '${trip.depDate}', '${trip.arrDate}')"><i class="bi bi-pencil"></i> Edit</button>
                    `;
                } else if (trip.status === 'cancelled') {
                    actionButtons = `
                        <button class="btn btn-success btn-sm flex-fill rounded-pill" onclick="updateTripStatus('${trip.id}', 'upcoming')"><i class="bi bi-arrow-up-circle"></i> Restore</button>
                        <button class="btn btn-warning btn-sm flex-fill rounded-pill text-dark" onclick="openRescheduleModal('${trip.id}', '${trip.depDate}', '${trip.arrDate}', '${trip.depTime}', '${trip.arrTime}')"><i class="bi bi-arrow-repeat"></i> Reschedule</button>
                        <button class="btn btn-danger btn-sm flex-fill rounded-pill" onclick="confirmDelete('users/${currentWorkspaceUid}/trips/${trip.id}')"><i class="bi bi-trash"></i> Delete</button>
                    `;
                } else if (trip.status === 'completed') {
                    actionButtons = `
                        <button class="btn btn-danger btn-sm w-100 rounded-pill mt-2" onclick="confirmDelete('users/${currentWorkspaceUid}/trips/${trip.id}')"><i class="bi bi-trash"></i> Delete Permanently</button>
                    `;
                }
            }

            const html = `
                <div class="col-md-6 col-lg-4">
                    <div class="card p-4 shadow-sm h-100">
                        <h5 class="fw-bold mb-3">${trip.from} → ${trip.to} <br><small class="text-muted fs-6">${formatDisplayDate(trip.depDate)} ${relativeBadge}</small></h5>
                        <p class="mb-3 text-muted text-sm flex-grow-1">
                            <strong>Mode:</strong> ${trip.type.charAt(0).toUpperCase() + trip.type.slice(1)}<br>
                            <strong>Time:</strong> ${trip.depTime} → ${trip.arrTime}<br>
                            ${trip.pnr ? `<strong>PNR:</strong> ${trip.pnr}<br>` : ''}
                            ${trip.airline ? `<strong>Airline:</strong> ${trip.airline}<br>` : ''}
                            ${trip.trainName ? `<strong>Train:</strong> ${trip.trainName}<br>` : ''}
                            ${trip.busOperator ? `<strong>Bus:</strong> ${trip.busOperator}<br>` : ''}
                            ${trip.ticketNo ? `<strong>Ticket No:</strong> ${trip.ticketNo}<br>` : ''}
                            ${trip.bookedFrom ? `<strong>Booked From:</strong> ${trip.bookedFrom}<br>` : ''}
                            ${trip.carDetails ? `<strong>Car Details:</strong> ${trip.carDetails}<br>` : ''}
                        </p>
                        <div class="d-flex flex-wrap gap-2 card-actions mt-auto">
                            ${actionButtons}
                        </div>
                    </div>
                </div>`;
                
            if (trip.status === 'upcoming') upcoming.innerHTML += html;
            else if (trip.status === 'completed') completed.innerHTML += html;
            else cancelled.innerHTML += html;
        });
    });
}

window.updateTripStatus = (id, newStatus) => {
    if (currentWorkspaceRole !== 'owner' && currentWorkspaceRole !== 'master') return alert('Permission denied');
    tripsRef.child(id).update({ status: newStatus });
};

window.confirmCancelTrip = (id) => {
    showConfirmModal(
        "Cancel Trip",
        "Are you sure you want to cancel this trip? It will be moved to your Cancelled Plans.",
        "Yes, Cancel It",
        () => { updateTripStatus(id, 'cancelled'); }
    );
};

const rescheduleModal = new bootstrap.Modal(document.getElementById('rescheduleModal'));
const editModal = new bootstrap.Modal(document.getElementById('editModal'));

window.openRescheduleModal = (id, dDate, aDate, dTime, aTime) => {
    document.getElementById('rescheduleId').value = id;
    document.getElementById('rescheduleDepDate').value = dDate;
    document.getElementById('rescheduleArrDate').value = aDate;
    document.getElementById('rescheduleDepTime').value = dTime;
    document.getElementById('rescheduleArrTime').value = aTime;
    rescheduleModal.show();
};

window.openEditModal = (id, from, to, dDate, aDate) => {
    document.getElementById('editId').value = id;
    document.getElementById('editFrom').value = from;
    document.getElementById('editTo').value = to;
    document.getElementById('editDepDate').value = dDate;
    document.getElementById('editArrDate').value = aDate;
    editModal.show();
};

document.getElementById('rescheduleForm').addEventListener('submit', (e) => {
    e.preventDefault();
    if (currentWorkspaceRole !== 'owner' && currentWorkspaceRole !== 'master') return alert('Permission denied');
    tripsRef.child(document.getElementById('rescheduleId').value).update({
        depDate: document.getElementById('rescheduleDepDate').value,
        arrDate: document.getElementById('rescheduleArrDate').value,
        depTime: document.getElementById('rescheduleDepTime').value,
        arrTime: document.getElementById('rescheduleArrTime').value,
        status: 'upcoming' 
    }).then(() => rescheduleModal.hide());
});

document.getElementById('editForm').addEventListener('submit', (e) => {
    e.preventDefault();
    if (currentWorkspaceRole !== 'owner' && currentWorkspaceRole !== 'master') return alert('Permission denied');
    tripsRef.child(document.getElementById('editId').value).update({
        from: document.getElementById('editFrom').value,
        to: document.getElementById('editTo').value,
        depDate: document.getElementById('editDepDate').value,
        arrDate: document.getElementById('editArrDate').value
    }).then(() => editModal.hide());
});