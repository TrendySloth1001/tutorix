/**
 * Static coaching masters data
 * Categories, subjects, working days options
 */

export const COACHING_CATEGORIES = [
    { id: 'COACHING', name: 'Coaching Institute', description: 'Competitive exam preparation', icon: 'school' },
    { id: 'TUITION', name: 'Tuition Center', description: 'Academic tuition classes', icon: 'menu_book' },
    { id: 'SCHOOL', name: 'School', description: 'Regular school education', icon: 'account_balance' },
    { id: 'COLLEGE', name: 'College/University', description: 'Higher education institute', icon: 'apartment' },
    { id: 'ONLINE', name: 'Online Academy', description: 'Primarily online courses', icon: 'computer' },
    { id: 'SKILL', name: 'Skill Training', description: 'Professional skill development', icon: 'engineering' },
    { id: 'LANGUAGE', name: 'Language Institute', description: 'Foreign language courses', icon: 'translate' },
    { id: 'ARTS', name: 'Arts Academy', description: 'Music, dance, fine arts', icon: 'palette' },
    { id: 'SPORTS', name: 'Sports Academy', description: 'Sports training', icon: 'sports' },
    { id: 'OTHER', name: 'Other', description: 'Other type of institution', icon: 'category' },
];

export const COACHING_SUBJECTS = [
    // School subjects
    { id: 'MATHEMATICS', name: 'Mathematics', category: 'Academic' },
    { id: 'PHYSICS', name: 'Physics', category: 'Academic' },
    { id: 'CHEMISTRY', name: 'Chemistry', category: 'Academic' },
    { id: 'BIOLOGY', name: 'Biology', category: 'Academic' },
    { id: 'ENGLISH', name: 'English', category: 'Academic' },
    { id: 'HINDI', name: 'Hindi', category: 'Academic' },
    { id: 'SOCIAL_STUDIES', name: 'Social Studies', category: 'Academic' },
    { id: 'COMPUTER_SCIENCE', name: 'Computer Science', category: 'Academic' },
    { id: 'ACCOUNTANCY', name: 'Accountancy', category: 'Commerce' },
    { id: 'BUSINESS_STUDIES', name: 'Business Studies', category: 'Commerce' },
    { id: 'ECONOMICS', name: 'Economics', category: 'Commerce' },

    // Competitive
    { id: 'JEE', name: 'JEE (Main + Advanced)', category: 'Competitive' },
    { id: 'NEET', name: 'NEET', category: 'Competitive' },
    { id: 'UPSC', name: 'UPSC/Civil Services', category: 'Competitive' },
    { id: 'CA', name: 'CA/Chartered Accountancy', category: 'Competitive' },
    { id: 'BANKING', name: 'Banking Exams', category: 'Competitive' },
    { id: 'SSC', name: 'SSC Exams', category: 'Competitive' },
    { id: 'GATE', name: 'GATE', category: 'Competitive' },
    { id: 'CAT', name: 'CAT/MBA Entrance', category: 'Competitive' },
    { id: 'CLAT', name: 'CLAT/Law Entrance', category: 'Competitive' },

    // Skills
    { id: 'CODING', name: 'Coding/Programming', category: 'Skills' },
    { id: 'WEB_DEV', name: 'Web Development', category: 'Skills' },
    { id: 'DATA_SCIENCE', name: 'Data Science', category: 'Skills' },
    { id: 'DIGITAL_MARKETING', name: 'Digital Marketing', category: 'Skills' },
    { id: 'GRAPHIC_DESIGN', name: 'Graphic Design', category: 'Skills' },

    // Languages
    { id: 'SPOKEN_ENGLISH', name: 'Spoken English', category: 'Language' },
    { id: 'IELTS', name: 'IELTS', category: 'Language' },
    { id: 'FRENCH', name: 'French', category: 'Language' },
    { id: 'GERMAN', name: 'German', category: 'Language' },
    { id: 'SPANISH', name: 'Spanish', category: 'Language' },
    { id: 'JAPANESE', name: 'Japanese', category: 'Language' },

    // Arts
    { id: 'CLASSICAL_MUSIC', name: 'Classical Music', category: 'Arts' },
    { id: 'WESTERN_MUSIC', name: 'Western Music', category: 'Arts' },
    { id: 'DANCE', name: 'Dance', category: 'Arts' },
    { id: 'PAINTING', name: 'Painting/Drawing', category: 'Arts' },
];

export const WORKING_DAYS = [
    { id: 'MON', name: 'Monday', short: 'M' },
    { id: 'TUE', name: 'Tuesday', short: 'T' },
    { id: 'WED', name: 'Wednesday', short: 'W' },
    { id: 'THU', name: 'Thursday', short: 'T' },
    { id: 'FRI', name: 'Friday', short: 'F' },
    { id: 'SAT', name: 'Saturday', short: 'S' },
    { id: 'SUN', name: 'Sunday', short: 'S' },
];

export const INDIAN_STATES = [
    { id: 'AN', name: 'Andaman and Nicobar Islands' },
    { id: 'AP', name: 'Andhra Pradesh' },
    { id: 'AR', name: 'Arunachal Pradesh' },
    { id: 'AS', name: 'Assam' },
    { id: 'BR', name: 'Bihar' },
    { id: 'CH', name: 'Chandigarh' },
    { id: 'CT', name: 'Chhattisgarh' },
    { id: 'DN', name: 'Dadra and Nagar Haveli' },
    { id: 'DD', name: 'Daman and Diu' },
    { id: 'DL', name: 'Delhi' },
    { id: 'GA', name: 'Goa' },
    { id: 'GJ', name: 'Gujarat' },
    { id: 'HR', name: 'Haryana' },
    { id: 'HP', name: 'Himachal Pradesh' },
    { id: 'JK', name: 'Jammu and Kashmir' },
    { id: 'JH', name: 'Jharkhand' },
    { id: 'KA', name: 'Karnataka' },
    { id: 'KL', name: 'Kerala' },
    { id: 'LA', name: 'Ladakh' },
    { id: 'LD', name: 'Lakshadweep' },
    { id: 'MP', name: 'Madhya Pradesh' },
    { id: 'MH', name: 'Maharashtra' },
    { id: 'MN', name: 'Manipur' },
    { id: 'ML', name: 'Meghalaya' },
    { id: 'MZ', name: 'Mizoram' },
    { id: 'NL', name: 'Nagaland' },
    { id: 'OR', name: 'Odisha' },
    { id: 'PY', name: 'Puducherry' },
    { id: 'PB', name: 'Punjab' },
    { id: 'RJ', name: 'Rajasthan' },
    { id: 'SK', name: 'Sikkim' },
    { id: 'TN', name: 'Tamil Nadu' },
    { id: 'TG', name: 'Telangana' },
    { id: 'TR', name: 'Tripura' },
    { id: 'UP', name: 'Uttar Pradesh' },
    { id: 'UK', name: 'Uttarakhand' },
    { id: 'WB', name: 'West Bengal' },
];

export function getCoachingMasters() {
    return {
        categories: COACHING_CATEGORIES,
        subjects: COACHING_SUBJECTS,
        workingDays: WORKING_DAYS,
        states: INDIAN_STATES,
    };
}

export function getSubjectsByCategory() {
    const grouped: Record<string, typeof COACHING_SUBJECTS> = {};
    for (const subject of COACHING_SUBJECTS) {
        if (!grouped[subject.category]) {
            grouped[subject.category] = [];
        }
        grouped[subject.category]!.push(subject);
    }
    return grouped;
}
