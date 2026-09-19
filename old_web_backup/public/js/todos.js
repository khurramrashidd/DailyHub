document.getElementById('todoForm').addEventListener('submit', (e) => {
    e.preventDefault();
    if (!todosRef) return;
    
    if (currentWorkspaceRole === 'view') return alert('Permission Denied.');

    const data = {
        title: document.getElementById('todoTitle').value,
        desc: document.getElementById('todoDesc').value,
        date: document.getElementById('todoDate').value,
        time: document.getElementById('todoTime').value,
        priority: document.getElementById('todoPriority').value,
        status: 'upcoming'
    };
    todosRef.push(data).then(() => document.getElementById('todoForm').reset());
});

function initTodosListener() {
    if(!todosRef) return;

    todosRef.on('value', snapshot => {
        const upcoming = document.getElementById('upcomingTodos');
        const completed = document.getElementById('completedTodos');
        const cancelled = document.getElementById('cancelledTodos');
        upcoming.innerHTML = ''; completed.innerHTML = ''; cancelled.innerHTML = '';
        
        let todosArray = [];
        if (snapshot.exists()) {
            snapshot.forEach(child => {
                todosArray.push({ id: child.key, ...child.val() });
            });
        }

        todosArray.sort((a, b) => {
            const da = a.date || '9999-12-31';
            const db = b.date || '9999-12-31';
            return new Date(da) - new Date(db);
        });

        todosArray.forEach(todo => {
            let priorityBadgeClass = 'bg-secondary';
            if(todo.priority === 'High') priorityBadgeClass = 'bg-danger';
            if(todo.priority === 'Medium') priorityBadgeClass = 'bg-warning text-dark';
            if(todo.priority === 'Low') priorityBadgeClass = 'bg-info text-dark';

            const relative = getRelativeStatus(todo.date);
            let dateBadgeClass = "bg-secondary";
            if (relative === "Today") dateBadgeClass = "bg-success";
            else if (relative === "Tomorrow") dateBadgeClass = "bg-warning text-dark";
            else if (relative.startsWith("In ")) dateBadgeClass = "bg-info text-dark";

            const relativeBadge = todo.date ? `<span class="badge ${dateBadgeClass} ms-2">${relative}</span>` : '';

            // 3. Generate Buttons Dynamically based on Status AND Collaborative Roles
            let actionButtons = '';
            const canModify = currentWorkspaceRole === 'owner' || currentWorkspaceRole === 'master';

            if (canModify) {
                if (todo.status === 'upcoming') {
                    actionButtons = `
                        <button class="btn btn-complete-action flex-fill rounded-pill" onclick="updateTodoStatus('${todo.id}', 'completed')"><i class="bi bi-check2"></i> Done</button>
                        <button class="btn btn-cancel-action flex-fill rounded-pill" onclick="confirmCancelTodo('${todo.id}')"><i class="bi bi-x-circle"></i> Cancel</button>
                    `;
                } else if (todo.status === 'cancelled') {
                    actionButtons = `
                        <button class="btn btn-success btn-sm flex-fill rounded-pill" onclick="updateTodoStatus('${todo.id}', 'upcoming')"><i class="bi bi-arrow-up-circle"></i> Restore</button>
                        <button class="btn btn-danger btn-sm flex-fill rounded-pill" onclick="confirmDelete('users/${currentWorkspaceUid}/todos/${todo.id}')"><i class="bi bi-trash"></i> Delete</button>
                    `;
                } else if (todo.status === 'completed') {
                    actionButtons = `
                        <button class="btn btn-danger btn-sm w-100 rounded-pill mt-2" onclick="confirmDelete('users/${currentWorkspaceUid}/todos/${todo.id}')"><i class="bi bi-trash"></i> Delete Permanently</button>
                    `;
                }
            }

            const html = `
                <div class="col-md-6 col-lg-4">
                    <div class="card p-4 shadow-sm h-100">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <h5 class="fw-bold mb-0">${todo.title}</h5>
                            <span class="badge ${priorityBadgeClass}">${todo.priority !== 'Select...' ? todo.priority : 'No Priority'}</span>
                        </div>
                        <p class="text-muted small mb-3 flex-grow-1">
                            ${todo.desc || ''}<br>
                            <span class="d-inline-block mt-2">
                                <strong>Due:</strong> ${formatDisplayDate(todo.date)} ${todo.time ? `at ${todo.time}` : ''} ${relativeBadge}
                            </span>
                        </p>
                        
                        <div class="d-flex flex-wrap gap-2 card-actions mt-auto">
                            ${actionButtons}
                        </div>
                    </div>
                </div>`;
                
            if (todo.status === 'upcoming') upcoming.innerHTML += html;
            else if (todo.status === 'completed') completed.innerHTML += html;
            else cancelled.innerHTML += html;
        });
    });
}

window.updateTodoStatus = (id, newStatus) => {
    if (currentWorkspaceRole !== 'owner' && currentWorkspaceRole !== 'master') return alert('Permission denied');
    todosRef.child(id).update({ status: newStatus });
};

window.confirmCancelTodo = (id) => {
    showConfirmModal(
        "Cancel To-Do",
        "Are you sure you want to cancel this task?",
        "Yes, Cancel It",
        () => { updateTodoStatus(id, 'cancelled'); }
    );
};