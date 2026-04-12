/**
 * Professional Writing Quality Assurance Script
 *
 * Validates and cleans any professional writing:
 * - Resume / CV
 * - Cover Letters
 * - Technical Articles
 * - Blog Posts
 * - Documentation
 * - Email Communications
 * - LinkedIn Posts
 * - Any professional text
 *
 * Features:
 * - Removes AI jargon and buzzwords
 * - Replaces em-dashes with appropriate alternatives
 * - Flags technical jargon
 * - Suggests improvements
 * - Works with HTML and plain text
 *
 * Usage:
 *   node professional-writing-qa.js <file.html>
 *   OR import as module:
 *   const { validateDocument, cleanDocument } = require('./professional-writing-qa.js');
 */

const fs = require('fs');
const path = require('path');

// Load forbidden words configuration
const forbiddenWordsPath = path.join(__dirname, 'forbidden-words.json');
const forbiddenConfig = JSON.parse(fs.readFileSync(forbiddenWordsPath, 'utf8'));

class ProfessionalWritingQA {
  constructor(config) {
    this.config = config;
    this.issues = [];
    this.suggestions = [];
  }

  /**
   * Extract text content from HTML
   */
  extractText(html) {
    // Remove script and style tags
    let text = html.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
    text = text.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');
    // Remove HTML tags
    text = text.replace(/<[^>]+>/g, '');
    // Decode HTML entities
    text = text.replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
    return text;
  }

  /**
   * Check for forbidden words
   */
  checkForbiddenWords(text) {
    const lowerText = text.toLowerCase();
    const allForbidden = [
      ...this.config.forbidden_words.ai_jargon,
      ...this.config.forbidden_words.overused_buzzwords,
      ...this.config.forbidden_words.vague_terms,
      ...this.config.forbidden_words.empty_phrases,
    ];

    allForbidden.forEach(word => {
      const regex = new RegExp(`\\b${word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'gi');
      const matches = text.match(regex);
      if (matches) {
        this.issues.push({
          type: 'forbidden_word',
          word,
          count: matches.length,
          severity: 'high'
        });
      }
    });

    // Check technical identifiers
    this.config.forbidden_patterns.excessive_technical_depth.avoid.forEach(term => {
      const regex = new RegExp(`\\b${term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'gi');
      const matches = text.match(regex);
      if (matches) {
        this.issues.push({
          type: 'excessive_technical',
          term,
          count: matches.length,
          severity: 'medium'
        });
      }
    });
  }

  /**
   * Check for em-dashes and en-dashes
   */
  checkDashes(text) {
    const emDashMatches = text.match(/—/g);
    const enDashMatches = text.match(/–/g);

    if (emDashMatches) {
      this.issues.push({
        type: 'em_dash',
        count: emDashMatches.length,
        severity: 'medium'
      });
    }

    if (enDashMatches) {
      this.issues.push({
        type: 'en_dash',
        count: enDashMatches.length,
        severity: 'low'
      });
    }
  }

  /**
   * Check sentence length
   */
  checkSentenceLength(text) {
    const sentences = text.match(/[^.!?]+[.!?]+/g) || [];
    const longSentences = sentences.filter(s => s.split(/\s+/).length > 25);

    if (longSentences.length > 0) {
      this.suggestions.push({
        type: 'long_sentences',
        count: longSentences.length,
        tip: 'Consider breaking up long sentences (>25 words) for better readability'
      });
    }
  }

  /**
   * Check paragraph structure
   */
  checkParagraphStructure(html) {
    const paragraphs = html.match(/<p[^>]*>.*?<\/p>/gi) || [];
    const liItems = html.match(/<li[^>]*>.*?<\/li>/gi) || [];

    // Flexible paragraph check - warn only if very short or very long
    if (paragraphs.length === 1 && liItems.length === 0) {
      this.suggestions.push({
        type: 'paragraph_count_low',
        current: paragraphs.length,
        tip: 'Document has only 1 paragraph. Consider breaking into multiple paragraphs for better structure.'
      });
    } else if (paragraphs.length > 10) {
      this.suggestions.push({
        type: 'paragraph_count_high',
        current: paragraphs.length,
        tip: 'Document has many paragraphs. Consider consolidating similar ideas.'
      });
    }
  }

  /**
   * Check word count
   */
  checkWordCount(text) {
    const wordCount = text.trim().split(/\s+/).length;

    if (wordCount < 100) {
      this.suggestions.push({
        type: 'word_count_very_low',
        count: wordCount,
        tip: 'Document is quite short. Aim for at least 150-200 words for professional writing.'
      });
    } else if (wordCount > 2000) {
      this.suggestions.push({
        type: 'word_count_high',
        count: wordCount,
        tip: 'Document is getting long. Consider breaking into sections or shortening.'
      });
    }
  }

  /**
   * Clean text by replacing forbidden words and fixing dashes
   */
  cleanText(text) {
    let cleaned = text;

    // Replace em-dashes with appropriate alternatives
    cleaned = cleaned.replace(/—/g, ',');
    cleaned = cleaned.replace(/–/g, '-');

    return cleaned;
  }

  /**
   * Run full validation
   */
  validate(html) {
    this.issues = [];
    this.suggestions = [];

    const text = this.extractText(html);

    this.checkForbiddenWords(text);
    this.checkDashes(text);
    this.checkSentenceLength(text);
    this.checkParagraphStructure(html);
    this.checkWordCount(text);

    return {
      text,
      issues: this.issues.sort((a, b) => {
        const severityMap = { high: 0, medium: 1, low: 2 };
        return (severityMap[a.severity] || 3) - (severityMap[b.severity] || 3);
      }),
      suggestions: this.suggestions,
      summary: {
        totalIssues: this.issues.length,
        totalSuggestions: this.suggestions.length,
        status: this.issues.length === 0 ? '✅ PASS' : '⚠️ ISSUES FOUND'
      }
    };
  }

  /**
   * Generate clean HTML by replacing problematic content
   */
  cleanHtml(html) {
    let cleaned = html;

    // Replace em-dashes
    cleaned = cleaned.replace(/—/g, ',');
    cleaned = cleaned.replace(/–/g, '-');

    return cleaned;
  }
}

/**
 * Export functions
 */
module.exports = {
  ProfessionalWritingQA,
  validateDocument: (html, config = forbiddenConfig) => {
    const qa = new ProfessionalWritingQA(config);
    return qa.validate(html);
  },
  cleanDocument: (html, config = forbiddenConfig) => {
    const qa = new ProfessionalWritingQA(config);
    return qa.cleanHtml(html);
  },
  // Backward compatibility
  validateCoverLetter: (html, config = forbiddenConfig) => {
    const qa = new ProfessionalWritingQA(config);
    return qa.validate(html);
  },
  cleanCoverLetter: (html, config = forbiddenConfig) => {
    const qa = new ProfessionalWritingQA(config);
    return qa.cleanHtml(html);
  }
};

// CLI Usage
if (require.main === module) {
  const filePath = process.argv[2];

  if (!filePath) {
    console.error('Usage: node professional-writing-qa.js <file.html>');
    process.exit(1);
  }

  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(1);
  }

  const html = fs.readFileSync(filePath, 'utf8');
  const qa = new ProfessionalWritingQA(forbiddenConfig);
  const result = qa.validate(html);

  // Print results
  console.log('\n📋 PROFESSIONAL WRITING VALIDATION REPORT');
  console.log('='.repeat(60));
  console.log(`File: ${filePath}`);
  console.log(`Status: ${result.summary.status}`);
  console.log(`Issues: ${result.summary.totalIssues} | Suggestions: ${result.summary.totalSuggestions}`);
  console.log('='.repeat(60));

  if (result.issues.length > 0) {
    console.log('\n⚠️  ISSUES:');
    result.issues.forEach((issue, idx) => {
      const severityEmoji = { high: '🔴', medium: '🟡', low: '🟢' }[issue.severity] || '⚪';
      console.log(`${idx + 1}. ${severityEmoji} [${issue.severity.toUpperCase()}] ${issue.type}`);
      if (issue.word) console.log(`   Word: "${issue.word}" (found ${issue.count} times)`);
      if (issue.term) console.log(`   Term: "${issue.term}" (found ${issue.count} times)`);
    });
  }

  if (result.suggestions.length > 0) {
    console.log('\n💡 SUGGESTIONS:');
    result.suggestions.forEach((suggestion, idx) => {
      console.log(`${idx + 1}. ${suggestion.tip}`);
    });
  }

  if (result.issues.length === 0 && result.suggestions.length === 0) {
    console.log('\n✅ Perfect! No issues found.');
  }

  console.log('\n' + '='.repeat(60));

  // Exit with appropriate code
  process.exit(result.issues.length > 0 ? 1 : 0);
}

