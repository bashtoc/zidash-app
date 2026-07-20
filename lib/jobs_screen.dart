import 'package:flutter/material.dart';
import 'auth_required_dialog.dart';
import 'become_creator_screen.dart';
import 'find_job_screen.dart';
import 'find_ugc_influencers_screen.dart';
import 'job_application_sheet.dart';
import 'post_job_screen.dart';
import 'services/api_service.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  late Future<List<dynamic>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _jobsFuture = ApiService.instance.jobs();
  }

  void _refreshJobs() {
    setState(() {
      _jobsFuture = ApiService.instance.jobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF66C665);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Jobs & Talent',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What would you like to do today?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),

              // find a job
              _buildJobOption(
                context,
                icon: Icons.search,
                title: 'Find a job',
                description: 'Browse through available vacancies and apply.',
                color: Colors.green.shade50,
                iconColor: primaryColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FindJobScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // post a job
              _buildJobOption(
                context,
                icon: Icons.add_business_outlined,
                title: 'Post a job',
                description:
                    'Hire professionals for your projects or business.',
                color: Colors.blue.shade50,
                iconColor: Colors.blue,
                onTap: () async {
                  final allowed = await requireAuthenticated(
                    context,
                    title: 'Sign up to post a job',
                    message:
                        'Create an account to hire professionals and manage job applications.',
                  );
                  if (!allowed || !context.mounted) return;
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PostJobScreen(),
                    ),
                  );
                  if (result == true) _refreshJobs();
                },
              ),

              const SizedBox(height: 16),

              // find UGC influencers
              _buildJobOption(
                context,
                icon: Icons.people_outline,
                title: 'Find UGC influencers',
                description: 'Connect with creators to promote your brand.',
                color: Colors.purple.shade50,
                iconColor: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FindUgcInfluencersScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Become an UGC influence
              _buildJobOption(
                context,
                icon: Icons.stars_outlined,
                title: 'Become an UGC influence',
                description: 'Monetize your creativity and influence.',
                color: Colors.orange.shade50,
                iconColor: Colors.orange,
                onTap: () async {
                  final allowed = await requireAuthenticated(
                    context,
                    title: 'Sign up to become a creator',
                    message:
                        'Create an account to build your creator profile and receive brand requests.',
                  );
                  if (!allowed || !context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BecomeCreatorScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
              const Text(
                'Jobs posted already',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              FutureBuilder<List<dynamic>>(
                future: _jobsFuture,
                builder: (context, snapshot) {
                  final jobs = snapshot.data;
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }
                  if (jobs == null || jobs.isEmpty) {
                    return Column(
                      children: [
                        _buildJobListing(
                          jobId: '',
                          title: 'Senior Product Designer',
                          company: 'Zidash Inc.',
                          location: 'Lagos, NG (Remote)',
                          salary: '₦800k - ₦1.2m',
                          time: '2h ago',
                          type: 'Full-time',
                        ),
                        _buildJobListing(
                          jobId: '',
                          title: 'UGC Content Creator',
                          company: 'FashionHub',
                          location: 'Abuja, NG',
                          salary: '₦50k / Video',
                          time: '5h ago',
                          type: 'Contract',
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: jobs.map((job) {
                      final item = job as Map<String, dynamic>;
                      final salaryMin = item['salaryMin'];
                      final salaryMax = item['salaryMax'];
                      return _buildJobListing(
                        jobId: item['id']?.toString() ?? '',
                        title: item['title']?.toString() ?? 'Untitled Job',
                        company: item['company']?.toString() ?? 'Company',
                        location: item['location']?.toString() ?? 'Remote',
                        salary: salaryMin == null && salaryMax == null
                            ? 'Salary open'
                            : '₦${salaryMin ?? 0} - ₦${salaryMax ?? salaryMin}',
                        time: 'Open',
                        type: _formatJobType(
                          item['employmentType']?.toString() ?? 'full_time',
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatJobType(String value) {
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join('-');
  }

  Widget _buildJobListing({
    required String jobId,
    required String title,
    required String company,
    required String location,
    required String salary,
    required String time,
    required String type,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF66C665).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    color: Color(0xFF66C665),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            company,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                location,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.payments_outlined,
                size: 16,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                salary,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              InkWell(
                onTap: () async {
                  final applied = await showJobApplicationSheet(
                    context,
                    jobId: jobId,
                    title: title,
                    company: company,
                  );
                  if (!mounted || !applied) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Application submitted.')),
                  );
                },
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'Apply Now',
                    style: TextStyle(
                      color: Color(0xFF66C665),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade300,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
