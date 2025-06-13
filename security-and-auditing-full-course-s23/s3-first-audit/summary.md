# S3. Your First Audit - PasswordStore

## **Phase 1: Scoping**


The Scoping phase is crucial for establishing the foundation of the security review. It defines the boundaries, expectations, and necessary prerequisites for a successful engagement.

### **Essentials for Accepting a Client Contract:**

- **Avoid Auditing Code from Etherscan Alone:** Relying solely on bytecode deployed on Etherscan is insufficient. Auditors must work with the original, verified source code.
- **"Rekt Test" Compliance:** The client's project should ideally pass most, if not all, of the "Rekt Test" questions (a pre-audit security checklist). If a client's project doesn't meet these basic security hygiene standards, it indicates a lack of maturity that could significantly hinder the review process.
- **Educating Clients:** While it's possible to take on clients with less mature codebases, auditors should emphasize the importance of robust testing practices and foundational security. This can sometimes lead to additional consulting work.
- **Minimal Assurance of Codebase Security:** Before starting the review, there must be a minimal level of assurance that the codebase is hosted securely (e.g., in a well-secured Git repository) and managed with appropriate access controls.
- **Onboarding Questions:** A set of minimal onboarding questions should be provided to the client. The client should complete these in detail, as their answers are critical for the audit's direction.

### **Minimal Onboarding Information from the Client:**

1. **Documentation for Business Logic:**
    - Provide clear and comprehensive documentation explaining the protocol's business logic. Many critical bugs stem from misunderstandings or flaws in the underlying business logic, not just coding errors.
2. **Lines of Code (LOC) & Complexity Metrics:**
    - Provide an estimate of the Lines of Code (LOC) and overall code complexity. This helps the audit firm gauge the scale of the project and set a realistic review period (start and end dates).
3. **Setup Instructions:**
    - Detailed instructions on how to set up the development environment, build the project, and run tests.
4. **Commit Hash:**
    - Specify the exact Git commit hash of the codebase to be reviewed. Auditing a moving target (code that is still being actively changed or has known unaddressed issues) can significantly increase complexity and waste time.
5. **Repository URL:**
    - Provide the link to the code repository (e.g., GitHub).
6. **In-scope vs. Out-of-scope Contracts:**
    - A clear list of contracts that are explicitly within the scope of the audit. If there are other related contracts or components (e.g., test suites, deployment scripts) where advice might be sought, this should be discussed and agreed upon with the client beforehand.
7. **Compatibilities:**
    - Specify crucial compatibility details: Solidity compiler (`solc`) version, target blockchain(s), token standards used (e.g., ERC-20, ERC-721), and any other relevant dependencies.
8. **Roles:**
    - Document all actors and their associated roles within the system (e.g., `owner`, `minter`, `user`). Clearly define what each role `should` and `should not` be able to do.
9. **Known Issues:**
    - List any existing bugs or issues in the specified commit that are known to the development team but will not be fixed as part of the current review's scope. This prevents auditors from wasting time on already identified problems.


## **Phase 2: Reconnaissance**


Reconnaissance is the initial deep dive into the protocol's mechanics, aiming to understand its complete architecture and functionality before active vulnerability hunting begins.

### **Tincho's Approach (A Recommended Strategy):**

1. **Read Documentation:**
    - Thoroughly read all official documentation provided by the client, whether in GitHub, a dedicated docs page, or whitepapers.
    - Utilize tools like `solidity-metrics` (often available as a VS Code extension) to generate diagrams and visualizations of the contract's structure.
2. **Analyze Lines of Code (LOC):**
    - Use tools like `cloc` (Count Lines of Code) to get a breakdown of lines per file. This data can be exported to CSV and imported into spreadsheets for further analysis of the codebase's size and distribution.
    - **Example:** `cloc ./src --by-file --csv --out=loc_result.csv`

### **Bottom-up Approach:**

- Start by understanding the most minimal or foundational parts of the code, then progressively move to more complex modules and interactions. This builds a solid mental model.

### **Understand & Break:**

- **Understand:** Focus on deeply understanding how each method and component works.
- **Break:** After understanding, actively think about how to break or abuse its intended functionality.
    - **Patrick's Advice:** When reviewing access control mechanisms, especially for contracts like `Ownable`, always check **who the actual actor is** (e.g., a multi-sig wallet, a DAO, an EOA). The direct "owner" might just be a proxy for a more complex entity.
    - **Example: Subtle Differences in ERC-20 Implementations:**
        
        ```solidity
        // Does this make sense in USDT?
        // USDT (Tether) does not return a boolean value from `transferFrom`,
        // unlike most other ERC-20 implementations which return `true`/`false`.
        // This can lead to unexpected behavior if not handled correctly.
        IERCO(_token).transfer(_to, _amount);
        
        ```
        
        This highlights the need to understand specific contract behaviors, not just generic standards.
        

### **Notes:**

- **Keep Quick Notes:** Maintain a running log of quick notes, thoughts, and observations within your project workspace. This can be a free-form brainstorming document.
- **In-code Comments:** Use temporary comments directly in the source code for quick classification (e.g., `// q: question to dev`, `// i: interesting finding`).
- **Friendly Format:** Develop your own concise format for categorizing these notes.
- **Rabbit Holes:** Be prepared to dive deep into complex sections ("rabbit holes") but also know when to pull back and re-evaluate if the current path isn't yielding results (similar to Depth-First Search but with a pragmatic target).

### **Test for Latent Bugs & Communication:**

- **Utilize Fuzzing (Foundry):** Actively use fuzzing tools like Foundry to explore edge cases and uncover subtle bugs that might not be immediately obvious.
- **Communicate with Developers:** This is paramount. Do not be afraid to ask questions to the protocol team. They possess crucial context and insights that no static analysis tool or independent review can provide.
- **Tincho's Insight:** By asking intelligent questions, you demonstrate expertise and ultimately gain the team's trust as an expert.

### **Other Advises:**

- **Continuous Learning:** Always be learning and exploring new tools and attack vectors. No one is perfect, and you will miss things.
- **Multi-angled Security:** Security must be viewed from different angles; auditing is just one piece of the overall security puzzle.
- **Balance Finding & Reporting:** Approximately 50% of the auditor's work is finding vulnerabilities, and the other 50% is effectively delivering a clear, readable, and actionable report.
- **Shared Responsibility:** An auditor is not solely responsible for making code bug-free. Security is a collaborative effort between the audit firm and the development team.


## **Phase 3: Vulnerability Identification**


This is the core phase where identified issues are formally documented and categorized. It involves leveraging the understanding gained in reconnaissance to pinpoint specific weaknesses.

### **Common Problems (Example: PasswordStore Contract):**

Let's illustrate common types of vulnerabilities using a hypothetical `PasswordStore` contract.

1. **Structural Problem: Private Variable Misconception**
    
    ```solidity
    string private s_password;
    ```
    
    - **Vulnerability:** The `private` keyword in Solidity only prevents other contracts from directly calling the variable. It does **not** make the data truly private or secret on the blockchain. Anyone can read the value of `s_password` directly from the blockchain state.
    - **Impact:** Sensitive information stored in `private` variables is publicly exposed.
2. **Missing Access Control**
    
    ```solidity
    // missing-access-control
    function setPassword(string memory newPassword) external {
        s_password = newPassword;
        emit SetNetPassword(); // Typo: Should be SetNewPassword()
    }
    ```
    
    - **Vulnerability:** This function lacks any access control checks, meaning `any user` can call `setPassword` and change the contract's password.
    - **Impact:** Complete compromise of password management, potentially leading to unauthorized access or denial of service.
3. **Comment Does Not Match Code**
    
    ```solidity
    /*
     * @notice This allows only the owner to retrieve the password.
     * @param newPassword The new password to set. // Mismatch
     */
    function getPassword() external view returns (string memory) {
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
        }
        return s_password;
    }
    ```
    
    - **Vulnerability:** The `@param newPassword` in the NatSpec comment is misleading because `getPassword` does not take any parameters. The comment describes a different function (`setPassword`).
    - **Impact:** Confusion for developers and auditors, leading to misinterpretations of the contract's functionality and potential logical errors.

### **Protocol Tests:**

- **Goal:** The ultimate goal is to "make the protocol safer" as a whole. This includes not just finding bugs but also improving the client's testing and engineering practices.
- **Hints from Tests:** Examining the client's existing test suite can provide valuable hints about the protocol's intended behavior (what it "should" or "should not" do).
- **Coverage:**
    - The `forge coverage` command provides a report on code coverage, indicating which lines of code were executed by tests.
    - **Limitation:** 100% code coverage does **not** mean all edge cases or attack vectors have been tested. For example, in the `PasswordStore` sample, the test suite might cover the `setPassword` function's execution but might miss a test case for a `non-owner` calling it (the missing access control vulnerability).



## **Phase 4: Reporting**


The reporting phase is where the auditor effectively communicates findings to the client. A well-structured report is crucial for the client to understand and address the identified issues.

### **Basic Findings Layout:**

A standard layout for each finding typically includes:

```markdown
### [S-#] TITLE (Root Cause + Impact)

**Description:**
[Detailed explanation of the vulnerability, referencing code snippets.]

**Impact:**
[Explanation of the potential consequences of the vulnerability.]

**Proof of Concept:**
[Code example or steps to reproduce the vulnerability, often in a test case format.]

**Recommended Mitigation:**
[Clear, actionable suggestions for how to fix the vulnerability.]

```

### **Breakdown of Each Section:**

1. **Title:**
    - A concise summary that clearly states the **root cause** of the vulnerability and its **significant impact** on the end-user or the protocol's integrity. (e.g., "Missing Access Control in `setPassword` leading to unauthorized password changes.")
2. **Description:**
    - Explain the vulnerable code in detail, leveraging blockchain-specific knowledge (EVM, Solidity specifics).
    - Describe the side effects or unintended behaviors that contradict the documented or assumed business logic.
3. **Proof of Concept (PoC) Code:**
    - Provide concrete code (often a test case) that unequivocally demonstrates the existence and exploitability of the problem. This is critical for convincing the client that it's a real issue.
    - In competitive audits, a strong PoC is often the primary evidence of a valid finding.
4. **Recommended Mitigation:**
    - As an auditor, you also act as an **educator**. Suggest clear, actionable solutions that will make the protocol more secure. These recommendations should be practical and align with best practices.