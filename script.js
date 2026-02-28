document.getElementById('predictionForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    // 1. Collect Course Data
    const courseRows = document.querySelectorAll('.course-row');
    const coursesArray = Array.from(courseRows).map(row => ({
        name: row.querySelector('.course-name').value,
        grade: parseFloat(row.querySelector('.course-grade').value)
    }));

    // 2. Collect AI Features
    const studentData = {
        ssc: parseFloat(document.getElementById('ssc').value),
        last: parseFloat(document.getElementById('last').value),
        attendance: parseInt(document.getElementById('attendance').value),
        preparation: parseInt(document.getElementById('preparation').value),
        income: 2, hometown: 1, department: 0, gaming: 2,
        courses: coursesArray
    };

    try {
        const response = await fetch('http://127.0.0.1:8000/predict', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(studentData)
        });

        const data = await response.json();
        const resultArea = document.getElementById('resultArea');
        const resultBox = document.getElementById('resultBox');
        resultArea.classList.remove('hidden');

        // Logic to show "Confidence in Success" vs "Risk of Failure"
        let displayScore;
        let scoreLabel;

        if (data.needs_resources) {
            // High Risk: Show the risk percentage
            displayScore = data.confidence_score;
            scoreLabel = "AI Habit Risk Prediction: " + displayScore + "% chance of falling behind.";
        } else {
            // Low Risk: Show the success confidence (100 - risk)
            displayScore = (100 - data.confidence_score).toFixed(2);
            scoreLabel = "AI Success Confidence: " + displayScore + "% chance of staying on track.";
        }

        // Apply UI Styling
        let htmlContent = `<p class="font-bold text-lg mb-1">${data.message}</p>`;
        htmlContent += `<p class="text-sm mb-3">🧠 ${scoreLabel}</p>`;

        const styles = {
            critical: "border-red-300 bg-red-50 text-red-800",
            subject_alert: "border-yellow-300 bg-yellow-50 text-yellow-800",
            habit_alert: "border-orange-300 bg-orange-50 text-orange-800",
            safe: "border-green-300 bg-green-50 text-green-800"
        };

        resultBox.className = `p-4 rounded-md border ${styles[data.alert_level]}`;
        
        //generate resource links from Neon
        if (data.resource_links && data.resource_links.length > 0) {
            htmlContent += `<p class="font-semibold text-sm mb-2">Recommended Foundational Resources:</p>`;
            htmlContent += `<div class="space-y-2 text-sm mt-1">`;
            data.resource_links.forEach(resource => {
                const icon = resource.resource_type === 'video' ? '🎥' : (resource.resource_type === 'PDF' ? '📄' : '🔗');
                htmlContent += `
                    <a href="${resource.url}" target="_blank" class="block p-3 border border-gray-200 rounded-md hover:bg-white hover:shadow transition duration-150">
                            <span class="mr-2">${icon}</span>
                            <span class="font-medium text-blue-700 hover:underline">${resource.title}</span>
                    </a>
                `;
            });

            htmlContent += `</div>`;
        }

        else if (data.subjects_to_focus.length > 0) {
            htmlContent += `<p class="font-semibold text-sm">Focus immediate attention on:</p>
                            <ul class="list-disc list-inside text-sm mt-1">
                                ${data.subjects_to_focus.map(s => `<li>${s}</li>`).join('')}
                            </ul>`;
        }

        resultBox.innerHTML = htmlContent;

    } catch (error) {
        console.error("Connection Error:", error);
        alert("Ensure FastAPI is running on port 8000");
    }
});

function addCourseRow() {
    const container = document.getElementById('courseContainer');
    const newRow = document.createElement('div');
    newRow.className = "flex gap-2 course-row";
    newRow.innerHTML = `
        <input type="text" placeholder="Course Name" class="flex-1 border border-gray-300 rounded-md p-2 text-sm course-name" required>
        <input type="number" placeholder="Grade" step="0.1" max="4.0" min="0" class="w-20 border border-gray-300 rounded-md p-2 text-sm course-grade" required>
        <button type="button" onclick="removeRow(this)" class="text-red-500 font-bold px-2">×</button>`;
    container.appendChild(newRow);
}

function removeRow(btn) { btn.parentElement.remove(); }