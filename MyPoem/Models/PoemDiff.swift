//
//  PoemDiff.swift
//  MyPoem
//
//  Created by Steven Richter on 6/2/25.
//


// MyPoem/Utilities/PoemDiff.swift
import Foundation

struct PoemDiff {
    enum DiffType {
        case unchanged
        case added
        case deleted
    }
    
    struct DiffSegment {
        let text: String
        let type: DiffType
        let wordCount: Int
    }
    
    /// Calculate word-level diff between two texts
    static func calculateDiff(from oldText: String, to newText: String) -> [DiffSegment] {
        let oldWords = tokenize(oldText)
        let newWords = tokenize(newText)
        
        // Simple LCS (Longest Common Subsequence) based diff
        let lcs = longestCommonSubsequence(oldWords.map { $0.text }, newWords.map { $0.text })
        var segments: [DiffSegment] = []
        
        var oldIndex = 0
        var newIndex = 0
        var lcsIndex = 0
        
        while oldIndex < oldWords.count || newIndex < newWords.count {
            // Check if we've reached the end of one array
            if oldIndex >= oldWords.count {
                // Remaining new words are additions
                let added = newWords[newIndex...].map { $0.text }.joined()
                if !added.isEmpty {
                    segments.append(DiffSegment(text: added, type: .added, wordCount: newWords.count - newIndex))
                }
                break
            }
            
            if newIndex >= newWords.count {
                // Remaining old words are deletions
                let deleted = oldWords[oldIndex...].map { $0.text }.joined()
                if !deleted.isEmpty {
                    segments.append(DiffSegment(text: deleted, type: .deleted, wordCount: oldWords.count - oldIndex))
                }
                break
            }
            
            // Check if current words match the next LCS element
            let oldWord = oldWords[oldIndex].text.trimmingCharacters(in: .whitespacesAndNewlines)
            let newWord = newWords[newIndex].text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if lcsIndex < lcs.count && oldWord == lcs[lcsIndex] && newWord == lcs[lcsIndex] {
                // Common word
                segments.append(DiffSegment(text: oldWords[oldIndex].text, type: .unchanged, wordCount: 1))
                oldIndex += 1
                newIndex += 1
                lcsIndex += 1
            } else if lcsIndex < lcs.count && oldWord == lcs[lcsIndex] {
                // New word added
                segments.append(DiffSegment(text: newWords[newIndex].text, type: .added, wordCount: 1))
                newIndex += 1
            } else if lcsIndex < lcs.count && newWord == lcs[lcsIndex] {
                // Old word deleted
                segments.append(DiffSegment(text: oldWords[oldIndex].text, type: .deleted, wordCount: 1))
                oldIndex += 1
            } else {
                // Both changed - show as delete + add
                segments.append(DiffSegment(text: oldWords[oldIndex].text, type: .deleted, wordCount: 1))
                segments.append(DiffSegment(text: newWords[newIndex].text, type: .added, wordCount: 1))
                oldIndex += 1
                newIndex += 1
            }
        }
        
        // Merge consecutive segments of the same type
        return mergeSegments(segments)
    }
    
    private struct Token {
        let text: String  // Includes whitespace/newlines
    }
    
    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var currentWord = ""
        var currentWhitespace = ""
        var inWord = false
        
        for char in text {
            if char.isWhitespace || char.isNewline {
                if inWord {
                    // End of word
                    tokens.append(Token(text: currentWord))
                    currentWord = ""
                    inWord = false
                }
                currentWhitespace.append(char)
            } else {
                if !currentWhitespace.isEmpty {
                    // Add whitespace as part of the previous token or as standalone
                    if !tokens.isEmpty && tokens[tokens.count - 1].text.last?.isWhitespace == false {
                        // Append whitespace to previous token
                        let lastToken = tokens.removeLast()
                        tokens.append(Token(text: lastToken.text + currentWhitespace))
                    }
                    currentWhitespace = ""
                }
                currentWord.append(char)
                inWord = true
            }
        }
        
        // Handle remaining content
        if !currentWord.isEmpty {
            tokens.append(Token(text: currentWord + currentWhitespace))
        }
        
        return tokens
    }
    
    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        // Build LCS length table
        for i in 1...m {
            for j in 1...n {
                if a[i-1].trimmingCharacters(in: .whitespacesAndNewlines) == 
                   b[j-1].trimmingCharacters(in: .whitespacesAndNewlines) {
                    dp[i][j] = dp[i-1][j-1] + 1
                } else {
                    dp[i][j] = max(dp[i-1][j], dp[i][j-1])
                }
            }
        }
        
        // Backtrack to find LCS
        var lcs: [String] = []
        var i = m, j = n
        
        while i > 0 && j > 0 {
            if a[i-1].trimmingCharacters(in: .whitespacesAndNewlines) == 
               b[j-1].trimmingCharacters(in: .whitespacesAndNewlines) {
                lcs.insert(a[i-1].trimmingCharacters(in: .whitespacesAndNewlines), at: 0)
                i -= 1
                j -= 1
            } else if dp[i-1][j] > dp[i][j-1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        
        return lcs
    }
    
    private static func mergeSegments(_ segments: [DiffSegment]) -> [DiffSegment] {
        guard !segments.isEmpty else { return [] }
        
        var merged: [DiffSegment] = []
        var currentText = ""
        var currentType = segments[0].type
        var currentWordCount = 0
        
        for segment in segments {
            if segment.type == currentType {
                currentText += segment.text
                currentWordCount += segment.wordCount
            } else {
                if !currentText.isEmpty {
                    merged.append(DiffSegment(text: currentText, type: currentType, wordCount: currentWordCount))
                }
                currentText = segment.text
                currentType = segment.type
                currentWordCount = segment.wordCount
            }
        }
        
        if !currentText.isEmpty {
            merged.append(DiffSegment(text: currentText, type: currentType, wordCount: currentWordCount))
        }
        
        return merged
    }
}
