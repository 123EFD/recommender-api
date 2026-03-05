document.getElementById('predictionForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    // 1. Collect Course Data
    const courseRows = document.querySelectorAll('.course-row');
    const coursesArray = Array.from(courseRows).map(row => ({
        name: row.querySelector('.course-name').value.toUpperCase().trim(),
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
        const resultMessage = document.getElementById('resultMessage');
        resultMessage.innerHTML = "";
        
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
            const seenResources = new Set();
            data.resource_links.forEach(resource => {
                if (!seenResources.has(resource.url)) {
                    const icon = resource.resource_type.toLowerCase() === 'video' ? '🎥' : (resource.resource_type === 'PDF' ? '📄' : '🔗');
                    htmlContent += `
                        <a href="${resource.url}" target="_blank" class="block p-3 border border-gray-200 bg-white rounded-md hover:shadow-md transition duration-150">
                            <div class="flex items-center">
                                <span class="mr-2">${icon}</span>
                                <div>
                                    <p class="text-xs font-bold text-gray-500 uppercase">${resource.course_code} - ${resource.subject_tag}</p>
                                    <p class="font-medium text-blue-700 hover:underline">${resource.title}</p>
                                
                                    ${resource.explanation ? `
                                        <p class="text-xs text-gray-600 mt-1 italic border-l-2 border-blue-200 pl-2">
                                            ${resource.explanation}
                                        </p>
                                    ` : ''}
                                </div>
                            </div>
                        </a>
                `;
                    seenResources.add(resource.url);
                }
            });

            htmlContent += `</div>`;
        } else if (data.subjects_to_focus.length > 0) {
            htmlContent += `<p class="font-semibold text-sm">Review habits for these codes:</p>
                            <ul class="list-disc list-inside text-sm mt-1">
                                ${data.subjects_to_focus.map(s => `<li>${s}</li>`).join('')}
                            </ul>`;
        }

        resultMessage.innerHTML = htmlContent;

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

let currentFilename= "";

async function handlePDFUpload() {
    const fileInput = document.getElementById('pdfFile');
    const urlInput = document.getElementById('pdfUrl');
    const statusElement = document.getElementById('uploadStatus');
    const pdfFrame = document.getElementById('pdfFrame');
    const pdfContainer = document.getElementById('pdfContainer');
    const processBtn = document.getElementById('processBtn');

    statusElement.innerHTML = '<span class="spinner"></span> AI is reading and indexing your PDF...';
    processBtn.disabled = true;
    processBtn.classList.add('opacity-50', 'cursor-not-allowed');

    let formData = new FormData();
    let response;

    try {
        if (fileInput.files.length > 0) {
            formData.append('file', fileInput.files[0]);
            response = await fetch('http://127.0.0.1:8000/upload-pdf', { method: 'POST', body: formData });
        
            //file preview
            const fileURL = URL.createObjectURL(fileInput.files[0]);
            pdfFrame.src = fileURL;
        } else if (urlInput.value.trim() !== "") {
            response = await fetch('http://127.0.0.1:8000/analyze-pdf-url', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ url: urlInput.value })
            });
            pdfFrame.src = urlInput.value;
        } else {
            alert("Please provide either a PDF file or URL");
            resetUploadBtn(processBtn, statusElement);
            return;
        }

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        if (data.message === "Success") {
            currentFilename = data.filename;
            statusElement.innerText = `✅ Loaded: ${data.filename} (${data.chunks_processed || data.chunks} chunks)`;
            pdfContainer.classList.remove('hidden');
        }
    } catch (error) {
        console.error("Error processing PDF:", error);
        statusElement.textContent = 'Error processing PDF: ' + error.message;
    } finally {
        processBtn.disabled = false;
        processBtn.classList.remove('opacity-50', 'cursor-not-allowed');
    }
}

async function askQuestion() {
    const input = document.getElementById('userQuestion');
    const chatMessages = document.getElementById('chatMessages');
    const question = input.value.trim();
    if (!question) return;

    // Show User Message
    chatMessages.innerHTML += `<div class="text-right"><p class="bg-blue-500 text-white p-2 rounded-lg inline-block">${question}</p></div>`;
    input.value = "";

    const loadingId = "ai-loading-" + Date.now();
    chatMessages.innerHTML += `<div id="${loadingId}" class="text-left"><p class="bg-gray-200 p-2 rounded-lg inline-block text-sm italic text-gray-500">AI is searching notes...</p></div>`;
    chatMessages.scrollTop = chatMessages.scrollHeight;

    try {
        const response = await fetch('http://127.0.0.1:8000/chat', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ question: question, filename: currentFilename })
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();

        // Remove thinking message and show real answer
        const loadingElement = document.getElementById(loadingId);
        if (loadingElement) loadingElement.remove();

        const formattedAnswer = marked.parse(data.answer);
        chatMessages.innerHTML += `<div class="text-left"><div class="bg-gray-200 p-3 rounded-lg inline-block text-sm prose">${formattedAnswer}</div></div>`;
    } catch (error) {
        const loadingElement = document.getElementById(loadingId);
        if (loadingElement) {
            if (error.message.includes("429")) {
                loadingElement.innerHTML = `<p class="text-orange-500 text-sm font-bold">⚠️ The AI is thinking too fast! Please wait 30 seconds and try asking again.</p>`;
            } else {
                loadingElement.innerHTML = `<p class="text-orange-500 text-sm font-bold">Error: ${error.message}</p>`;
            }
        }
    }
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

//sidebar elements
const menuBtn = document.getElementById('menuBtn');
const sidebar = document.getElementById('sidebar');
const overlap = document.getElementById('overlap');
const pdfLibraryList = document.getElementById('pdfLibraryList');

//toggle sidebar logic
menuBtn.addEventListener('click', () => {
    sidebar.classList.toggle('-translate-x-full');
    overlay.classList.toggle('opacity-50');
    overlay.classList.toggle('pointer-events-auto');
    if (!sidebar.classList.contains('-translate-x-full')) {
        refreshLibrary(); // Fetch list when opening
    }
});

overlay.addEventListener('click', () => {
    sidebar.classList.add('-translate-x-full');
    overlay.classList.remove('opacity-50', 'pointer-events-auto');
});

// 2. Fetch and Display Library
async function refreshLibrary() {
    try {
        const response = await fetch('http://127.0.0.1:8000/library');
        const files = await response.json();
        
        if (files.length === 0) {
            pdfLibraryList.innerHTML = '<p class="text-gray-400 italic">Library is empty.</p>';
            return;
        }

        pdfLibraryList.innerHTML = files.map(filename => `
            <div onclick="selectLibraryFile('${filename}')" class="p-3 bg-gray-50 rounded-lg border border-gray-200 hover:bg-blue-50 hover:border-blue-300 cursor-pointer transition-all truncate group">
                <span class="mr-2">📄</span>
                <span class="text-gray-700 font-medium group-hover:text-blue-700">${filename}</span>
            </div>
        `).join('');
    } catch (err) {
        console.error("Library Error:", err);
    }
}

// 3. Select a file from History
function selectLibraryFile(filename) {
    currentFilename = filename;
    
    // Update the UI
    document.getElementById('uploadStatus').innerHTML = `✅ <b>Active Subject:</b> ${filename}`;
    document.getElementById('pdfViewerContainer').classList.remove('hidden');
    
    // Note:Will need to integrate with Firebase/AWS S3
    // Since we don't store the full file URL in the vector DB,
    // we can't show the PDF in the iframe unless it was just uploaded.
    // For now, we clear the iframe to show we switched subjects.
    document.getElementById('pdfFrame').src = ""; 
    
    // Clear chat and Close sidebar
    document.getElementById('chatMessages').innerHTML = `<p class="text-gray-500 italic">Switched to: ${filename}</p>`;
    sidebar.classList.add('-translate-x-full');
    overlay.classList.remove('opacity-50', 'pointer-events-auto');
}