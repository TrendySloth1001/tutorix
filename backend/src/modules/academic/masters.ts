/**
 * Static academic masters data for onboarding
 * All dropdown options, boards, classes, streams, competitive exams, subjects
 */

export const BOARDS = [
    { id: 'CBSE', name: 'CBSE', fullName: 'Central Board of Secondary Education' },
    { id: 'ICSE', name: 'ICSE', fullName: 'Indian Certificate of Secondary Education' },
    { id: 'ISC', name: 'ISC', fullName: 'Indian School Certificate (Class 11-12)' },
    { id: 'STATE_MH', name: 'Maharashtra State Board', fullName: 'Maharashtra State Board of Secondary and Higher Secondary Education' },
    { id: 'STATE_UP', name: 'UP Board', fullName: 'Uttar Pradesh Madhyamik Shiksha Parishad' },
    { id: 'STATE_MP', name: 'MP Board', fullName: 'Madhya Pradesh Board of Secondary Education' },
    { id: 'STATE_RJ', name: 'Rajasthan Board', fullName: 'Board of Secondary Education, Rajasthan' },
    { id: 'STATE_GJ', name: 'Gujarat Board', fullName: 'Gujarat Secondary and Higher Secondary Education Board' },
    { id: 'STATE_KA', name: 'Karnataka Board', fullName: 'Karnataka Secondary Education Examination Board' },
    { id: 'STATE_TN', name: 'Tamil Nadu Board', fullName: 'Tamil Nadu Board of Secondary Education' },
    { id: 'STATE_AP', name: 'Andhra Pradesh Board', fullName: 'Board of Intermediate Education, Andhra Pradesh' },
    { id: 'STATE_TS', name: 'Telangana Board', fullName: 'Telangana State Board of Intermediate Education' },
    { id: 'STATE_WB', name: 'West Bengal Board', fullName: 'West Bengal Board of Secondary Education' },
    { id: 'STATE_KL', name: 'Kerala Board', fullName: 'Kerala Board of Public Examinations' },
    { id: 'IB', name: 'IB', fullName: 'International Baccalaureate' },
    { id: 'IGCSE', name: 'IGCSE', fullName: 'International General Certificate of Secondary Education' },
    { id: 'NIOS', name: 'NIOS', fullName: 'National Institute of Open Schooling' },
    { id: 'OTHER', name: 'Other', fullName: 'Other Board' },
];

export const CLASSES = [
    // Pre-Primary
    { id: 'NURSERY', name: 'Nursery', group: 'Pre-Primary', order: 1 },
    { id: 'LKG', name: 'LKG', group: 'Pre-Primary', order: 2 },
    { id: 'UKG', name: 'UKG', group: 'Pre-Primary', order: 3 },
    // Primary
    { id: 'CLASS_1', name: 'Class 1', group: 'Primary', order: 4 },
    { id: 'CLASS_2', name: 'Class 2', group: 'Primary', order: 5 },
    { id: 'CLASS_3', name: 'Class 3', group: 'Primary', order: 6 },
    { id: 'CLASS_4', name: 'Class 4', group: 'Primary', order: 7 },
    { id: 'CLASS_5', name: 'Class 5', group: 'Primary', order: 8 },
    // Middle School
    { id: 'CLASS_6', name: 'Class 6', group: 'Middle School', order: 9 },
    { id: 'CLASS_7', name: 'Class 7', group: 'Middle School', order: 10 },
    { id: 'CLASS_8', name: 'Class 8', group: 'Middle School', order: 11 },
    // Secondary
    { id: 'CLASS_9', name: 'Class 9', group: 'Secondary', order: 12 },
    { id: 'CLASS_10', name: 'Class 10', group: 'Secondary', order: 13 },
    // Higher Secondary
    { id: 'CLASS_11', name: 'Class 11', group: 'Higher Secondary', order: 14, requiresStream: true },
    { id: 'CLASS_12', name: 'Class 12', group: 'Higher Secondary', order: 15, requiresStream: true },
    // Repeater / Dropper
    { id: 'DROPPER', name: 'Dropper / Gap Year', group: 'Competitive Prep', order: 16, isCompetitiveOnly: true },
    // College / Graduation
    { id: 'UG_YEAR_1', name: '1st Year (UG)', group: 'Undergraduate', order: 17 },
    { id: 'UG_YEAR_2', name: '2nd Year (UG)', group: 'Undergraduate', order: 18 },
    { id: 'UG_YEAR_3', name: '3rd Year (UG)', group: 'Undergraduate', order: 19 },
    { id: 'UG_YEAR_4', name: '4th Year (UG)', group: 'Undergraduate', order: 20 },
    { id: 'PG', name: 'Post Graduate', group: 'Postgraduate', order: 21 },
    { id: 'OTHER', name: 'Other', group: 'Other', order: 99 },
];

export const STREAMS = [
    { id: 'SCIENCE_PCM', name: 'Science (PCM)', description: 'Physics, Chemistry, Mathematics', forClasses: ['CLASS_11', 'CLASS_12', 'DROPPER'] },
    { id: 'SCIENCE_PCB', name: 'Science (PCB)', description: 'Physics, Chemistry, Biology', forClasses: ['CLASS_11', 'CLASS_12', 'DROPPER'] },
    { id: 'SCIENCE_PCMB', name: 'Science (PCMB)', description: 'Physics, Chemistry, Math & Biology', forClasses: ['CLASS_11', 'CLASS_12', 'DROPPER'] },
    { id: 'COMMERCE', name: 'Commerce', description: 'Accounts, Business Studies, Economics', forClasses: ['CLASS_11', 'CLASS_12', 'DROPPER'] },
    { id: 'COMMERCE_MATHS', name: 'Commerce with Maths', description: 'Commerce subjects with Mathematics', forClasses: ['CLASS_11', 'CLASS_12', 'DROPPER'] },
    { id: 'ARTS', name: 'Arts / Humanities', description: 'History, Political Science, Sociology', forClasses: ['CLASS_11', 'CLASS_12', 'DROPPER'] },
    { id: 'VOCATIONAL', name: 'Vocational', description: 'Skill-based courses', forClasses: ['CLASS_11', 'CLASS_12'] },
];

export const COMPETITIVE_EXAMS = [
    // Engineering
    { id: 'JEE_MAIN', name: 'JEE Main', category: 'Engineering', description: 'Joint Entrance Examination Main' },
    { id: 'JEE_ADVANCED', name: 'JEE Advanced', category: 'Engineering', description: 'For IIT admission' },
    { id: 'BITSAT', name: 'BITSAT', category: 'Engineering', description: 'BITS Pilani Admission Test' },
    { id: 'VITEEE', name: 'VITEEE', category: 'Engineering', description: 'VIT Engineering Entrance Exam' },
    { id: 'SRMJEEE', name: 'SRMJEEE', category: 'Engineering', description: 'SRM Joint Engineering Entrance Exam' },
    { id: 'MHT_CET', name: 'MHT CET', category: 'Engineering', description: 'Maharashtra Common Entrance Test' },
    { id: 'WBJEE', name: 'WBJEE', category: 'Engineering', description: 'West Bengal Joint Entrance Exam' },
    
    // Medical
    { id: 'NEET_UG', name: 'NEET UG', category: 'Medical', description: 'National Eligibility cum Entrance Test' },
    { id: 'AIIMS', name: 'AIIMS', category: 'Medical', description: 'All India Institute of Medical Sciences' },
    { id: 'NEET_PG', name: 'NEET PG', category: 'Medical', description: 'For MD/MS admission' },
    
    // Commerce & CA
    { id: 'CA_FOUNDATION', name: 'CA Foundation', category: 'Commerce', description: 'Chartered Accountancy Foundation' },
    { id: 'CA_INTER', name: 'CA Intermediate', category: 'Commerce', description: 'Chartered Accountancy Intermediate' },
    { id: 'CA_FINAL', name: 'CA Final', category: 'Commerce', description: 'Chartered Accountancy Final' },
    { id: 'CS', name: 'CS', category: 'Commerce', description: 'Company Secretary' },
    { id: 'CMA', name: 'CMA', category: 'Commerce', description: 'Cost Management Accountant' },
    { id: 'CLAT', name: 'CLAT', category: 'Law', description: 'Common Law Admission Test' },
    
    // Government & Defense
    { id: 'UPSC_CSE', name: 'UPSC CSE', category: 'Government', description: 'Civil Services Examination' },
    { id: 'SSC_CGL', name: 'SSC CGL', category: 'Government', description: 'Combined Graduate Level' },
    { id: 'BANK_PO', name: 'Bank PO', category: 'Government', description: 'Bank Probationary Officer' },
    { id: 'NDA', name: 'NDA', category: 'Defense', description: 'National Defence Academy' },
    { id: 'CDS', name: 'CDS', category: 'Defense', description: 'Combined Defence Services' },
    
    // Design & Architecture
    { id: 'NID', name: 'NID', category: 'Design', description: 'National Institute of Design' },
    { id: 'NIFT', name: 'NIFT', category: 'Design', description: 'National Institute of Fashion Technology' },
    { id: 'NATA', name: 'NATA', category: 'Architecture', description: 'National Aptitude Test in Architecture' },
    { id: 'JEE_PAPER_2', name: 'JEE Paper 2 (B.Arch)', category: 'Architecture', description: 'For B.Arch admission' },
    
    // Management & MBA
    { id: 'CAT', name: 'CAT', category: 'Management', description: 'Common Admission Test (IIMs)' },
    { id: 'XAT', name: 'XAT', category: 'Management', description: 'Xavier Aptitude Test' },
    { id: 'MAT', name: 'MAT', category: 'Management', description: 'Management Aptitude Test' },
    
    // Science Olympiads
    { id: 'NTSE', name: 'NTSE', category: 'Olympiad', description: 'National Talent Search Examination' },
    { id: 'KVPY', name: 'KVPY', category: 'Olympiad', description: 'Kishore Vaigyanik Protsahan Yojana' },
    { id: 'OLYMPIAD_MATH', name: 'Math Olympiad', category: 'Olympiad', description: 'International Mathematics Olympiad' },
    { id: 'OLYMPIAD_SCIENCE', name: 'Science Olympiad', category: 'Olympiad', description: 'National Science Olympiad' },
    
    // Other
    { id: 'CUET', name: 'CUET', category: 'University', description: 'Common University Entrance Test' },
    { id: 'OTHER', name: 'Other', category: 'Other', description: 'Other competitive exam' },
];

export const SUBJECTS = [
    // Core subjects - all classes
    { id: 'MATHEMATICS', name: 'Mathematics', forStreams: ['SCIENCE_PCM', 'SCIENCE_PCMB', 'COMMERCE_MATHS'], forClasses: 'all' },
    { id: 'ENGLISH', name: 'English', forStreams: 'all', forClasses: 'all' },
    { id: 'HINDI', name: 'Hindi', forStreams: 'all', forClasses: 'all' },
    
    // Science subjects
    { id: 'PHYSICS', name: 'Physics', forStreams: ['SCIENCE_PCM', 'SCIENCE_PCB', 'SCIENCE_PCMB'], forClasses: ['CLASS_9', 'CLASS_10', 'CLASS_11', 'CLASS_12', 'DROPPER'] },
    { id: 'CHEMISTRY', name: 'Chemistry', forStreams: ['SCIENCE_PCM', 'SCIENCE_PCB', 'SCIENCE_PCMB'], forClasses: ['CLASS_9', 'CLASS_10', 'CLASS_11', 'CLASS_12', 'DROPPER'] },
    { id: 'BIOLOGY', name: 'Biology', forStreams: ['SCIENCE_PCB', 'SCIENCE_PCMB'], forClasses: ['CLASS_9', 'CLASS_10', 'CLASS_11', 'CLASS_12', 'DROPPER'] },
    { id: 'SCIENCE', name: 'Science', forStreams: 'all', forClasses: ['CLASS_1', 'CLASS_2', 'CLASS_3', 'CLASS_4', 'CLASS_5', 'CLASS_6', 'CLASS_7', 'CLASS_8'] },
    
    // Social Studies
    { id: 'SOCIAL_STUDIES', name: 'Social Studies', forStreams: 'all', forClasses: ['CLASS_1', 'CLASS_2', 'CLASS_3', 'CLASS_4', 'CLASS_5', 'CLASS_6', 'CLASS_7', 'CLASS_8', 'CLASS_9', 'CLASS_10'] },
    { id: 'HISTORY', name: 'History', forStreams: ['ARTS'], forClasses: ['CLASS_11', 'CLASS_12'] },
    { id: 'GEOGRAPHY', name: 'Geography', forStreams: ['ARTS', 'COMMERCE'], forClasses: ['CLASS_11', 'CLASS_12'] },
    { id: 'POLITICAL_SCIENCE', name: 'Political Science', forStreams: ['ARTS'], forClasses: ['CLASS_11', 'CLASS_12'] },
    { id: 'SOCIOLOGY', name: 'Sociology', forStreams: ['ARTS'], forClasses: ['CLASS_11', 'CLASS_12'] },
    { id: 'PSYCHOLOGY', name: 'Psychology', forStreams: ['ARTS'], forClasses: ['CLASS_11', 'CLASS_12'] },
    
    // Commerce subjects
    { id: 'ACCOUNTANCY', name: 'Accountancy', forStreams: ['COMMERCE', 'COMMERCE_MATHS'], forClasses: ['CLASS_11', 'CLASS_12'] },
    { id: 'BUSINESS_STUDIES', name: 'Business Studies', forStreams: ['COMMERCE', 'COMMERCE_MATHS'], forClasses: ['CLASS_11', 'CLASS_12'] },
    { id: 'ECONOMICS', name: 'Economics', forStreams: ['COMMERCE', 'COMMERCE_MATHS', 'ARTS'], forClasses: ['CLASS_11', 'CLASS_12'] },
    
    // Computer
    { id: 'COMPUTER_SCIENCE', name: 'Computer Science', forStreams: ['SCIENCE_PCM', 'COMMERCE_MATHS'], forClasses: ['CLASS_11', 'CLASS_12'] },
    { id: 'INFORMATICS_PRACTICES', name: 'Informatics Practices', forStreams: 'all', forClasses: ['CLASS_11', 'CLASS_12'] },
    
    // Languages
    { id: 'SANSKRIT', name: 'Sanskrit', forStreams: 'all', forClasses: 'all' },
    { id: 'FRENCH', name: 'French', forStreams: 'all', forClasses: 'all' },
    { id: 'GERMAN', name: 'German', forStreams: 'all', forClasses: 'all' },
    { id: 'SPANISH', name: 'Spanish', forStreams: 'all', forClasses: 'all' },
    { id: 'REGIONAL_LANGUAGE', name: 'Regional Language', forStreams: 'all', forClasses: 'all' },
    
    // Arts
    { id: 'FINE_ARTS', name: 'Fine Arts', forStreams: ['ARTS'], forClasses: ['CLASS_11', 'CLASS_12'] },
    { id: 'MUSIC', name: 'Music', forStreams: 'all', forClasses: 'all' },
    { id: 'PHYSICAL_EDUCATION', name: 'Physical Education', forStreams: 'all', forClasses: ['CLASS_11', 'CLASS_12'] },
    
    // Other
    { id: 'ENVIRONMENTAL_STUDIES', name: 'Environmental Studies', forStreams: 'all', forClasses: ['CLASS_1', 'CLASS_2', 'CLASS_3', 'CLASS_4', 'CLASS_5'] },
    { id: 'GENERAL_KNOWLEDGE', name: 'General Knowledge', forStreams: 'all', forClasses: 'all' },
];

// Helper to get the full masters object
export function getAcademicMasters() {
    return {
        boards: BOARDS,
        classes: CLASSES,
        streams: STREAMS,
        competitiveExams: COMPETITIVE_EXAMS,
        subjects: SUBJECTS,
    };
}

// Categorized view for competitive exams
export function getCompetitiveExamsByCategory() {
    const categories: Record<string, typeof COMPETITIVE_EXAMS> = {};
    for (const exam of COMPETITIVE_EXAMS) {
        if (!categories[exam.category]) {
            categories[exam.category] = [];
        }
        categories[exam.category]!.push(exam);
    }
    return categories;
}

// Get classes grouped
export function getClassesGrouped() {
    const groups: Record<string, typeof CLASSES> = {};
    for (const cls of CLASSES) {
        if (!groups[cls.group]) {
            groups[cls.group] = [];
        }
        groups[cls.group]!.push(cls);
    }
    return groups;
}

// Filter subjects by class and stream
export function getSubjectsForClassAndStream(classId: string, streamId?: string) {
    return SUBJECTS.filter(subject => {
        const classMatch = subject.forClasses === 'all' || 
            (Array.isArray(subject.forClasses) && subject.forClasses.includes(classId));
        
        if (!streamId) return classMatch;
        
        const streamMatch = subject.forStreams === 'all' ||
            (Array.isArray(subject.forStreams) && subject.forStreams.includes(streamId));
        
        return classMatch && streamMatch;
    });
}
